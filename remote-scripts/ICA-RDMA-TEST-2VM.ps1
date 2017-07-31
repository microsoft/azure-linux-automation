#author - vhisav@microsoft.com

Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
#$isDeployed = "ICA-RG-M1S1-SS-U16HPC-7-31-19-21-2052"
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
#        $allVMData = GetAllDeployementData -ResourceGroups $isDeployed
#        Set-Variable -Name allVMData -Value $allVMData -Scope Global
        $noServer = $true
		$noClient = $true
		$clientMachines = @()
		$slaveHostnames = ""
		foreach ( $vmData in $allVMData )
		{
			if ( $vmData.RoleName -imatch "Server" )
			{
				$serverVMData = $vmData
				$noServer = $false

			}
			elseif ( $vmData.RoleName -imatch "Client" )
			{
				$clientMachines = $vmData
				$noClient = $fase
				if ( $slaveHostnames )
				{
					$slaveHostnames += "," + $vmData.RoleName
				}
				else
				{
					$slaveHostnames = $vmData.RoleName
				}
			}
		}
		if ( $noServer )
		{
			Throw "No any server VM defined. Be sure that, server VM role name matches with the pattern `"*server*`". Aborting Test."
		}
		if ( $noSlave )
		{
			Throw "No any client VM defined. Be sure that, client machine role names matches with pattern `"*client*`" Aborting Test."
		}
		if ($serverVMData.InstanceSize -imatch "Standard_NC")
		{
			LogMsg "Waiting 5 minutes to finish RDMA update for NC series VMs."
			sleep -Seconds 300
		}
		#region CONFIGURE VMs for TEST

		LogMsg "SERVER VM details :"
		LogMsg "  RoleName : $($serverVMData.RoleName)"
		LogMsg "  Public IP : $($serverVMData.PublicIP)"
		LogMsg "  SSH Port : $($serverVMData.SSHPort)"
		$i = 1
		foreach ( $clientVMData in $clientMachines )
		{
			LogMsg "CLIENT VM #$i details :"
			LogMsg "  RoleName : $($clientVMData.RoleName)"
			LogMsg "  Public IP : $($clientVMData.PublicIP)"
			LogMsg "  SSH Port : $($clientVMData.SSHPort)"		
		}
		#
		# PROVISION VMS FOR LISA WILL ENABLE ROOT USER AND WILL MAKE ENABLE PASSWORDLESS AUTHENTICATION ACROSS ALL VMS IN SAME HOSTED SERVICE.	
		#
		
		ProvisionVMsForLisa -allVMData $allVMData -installPackagesOnRoleNames "none"

		#endregion

		#region Provision VMs for RDMA tests

		#region Generate constants.sh

		LogMsg "Generating constansts.sh ..."
		$constantsFile = ".\$LogDir\constants.sh"
		#foreach ($testParam in $currentTestData.params )
		#{
		#	Add-Content -Value "$testParam" -Path $constantsFile
		#	LogMsg "$testParam added to constansts.sh"
		#}

		Add-Content -Value "master=`"$($serverVMData.RoleName)`"" -Path $constantsFile
		LogMsg "master=$($serverVMData.RoleName) added to constansts.sh"


		Add-Content -Value "slaves=`"$slaveHostnames`"" -Path $constantsFile
		LogMsg "slaves=$slaveHostnames added to constansts.sh"

		Add-Content -Value "rdmaRun=`"yes`"" -Path $constantsFile
		LogMsg "rdmaRun=yes added to constansts.sh"

		Add-Content -Value "user=`"$user`"" -Path $constantsFile
		LogMsg "user=$user added to constansts.sh"
		LogMsg "constanst.sh created successfully..."
		#endregion		

		#region Generate etc-hosts.txt file
		$hostsFile = ".\$LogDir\etc-hosts.txt"
		foreach ( $vmDetails in $allVMData )
		{
			Add-Content -Value "$($vmDetails.InternalIP)`t$($vmDetails.RoleName)" -Path "$hostsFile"
			LogMsg "$($vmDetails.InternalIP)`t$($vmDetails.RoleName) added to etc-hosts.txt" 
		}
		#endregion

		#region Upload files to master VM...
		Set-Content -Value "/home/$user/TestRDMA.sh -user $user &> rdmaConsole.txt" -Path "$LogDir\StartRDMA.sh"
		Set-Content -Value "*			   hard	memlock			unlimited" -Path "$LogDir\limits.conf"
		Add-Content -Value "*			   soft	memlock			unlimited" -Path "$LogDir\limits.conf"
		$out = .\tools\dos2unix.exe "$LogDir\limits.conf" 2>&1
		LogMsg $out
		RemoteCopy -uploadTo $serverVMData.PublicIP -port $serverVMData.SSHPort -files "$constantsFile,$hostsFile,.\remote-scripts\TestRDMA.sh,.\$LogDir\StartRDMA.sh,.\$LogDir\limits.conf" -username $user -password $password -upload
		#endregion

		#region Install LIS-RDMA drivers..

		$osRelease = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "cat /etc/*release*" -ignoreLinuxExitCode
		$modinfo_hv_vmbus = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "lsmod | grep hv_network_direct"
		if (!( $modinfo_hv_vmbus -imatch "hv_network_direct" ))
		{
			LogMsg "RDMA LIS Drivers not installed. RDMA drivers will be installed now..."
			LogMsg $modinfo_hv_vmbus
			Add-Content -Value "rdmaPrepare=`"yes`"" -Path $constantsFile
			LogMsg "rdmaPrepare=yes added to constansts.sh"
			
			if ( $osRelease -imatch "CentOS Linux release 7.1.")
			{
				$LIS4folder = "RHEL71"
			}
			if ( $osRelease -imatch "CentOS Linux release 7.0.")
			{
				$LIS4folder = "RHEL70"
			}
			if ( $osRelease -imatch "CentOS Linux release 6.5")
			{
				$LIS4folder = "RHEL65"
			}
		
			$LIS4IntallCommand = "tar -xf lis-4.0.11-RDMA.tar && chmod +x $LIS4folder/install.sh && cd $LIS4folder && ./install.sh"
			$LIS4InstallJobs = @()
			foreach ( $vm in $allVMData )
			{   
				#Install LIS4 RDMA drivers...
				LogMsg "Setting contents of /etc/security/limits.conf..."
				$out = .\tools\dos2unix.exe ".\$LogDir\limits.conf" 2>&1
				LogMsg $out
				RemoteCopy -uploadTo $vm.PublicIP -port $vm.SSHPort -files ".\$LogDir\limits.conf" -username $user -password $password -upload
				$out = RunLinuxCmd -runAsSudo -ip $vm.PublicIP -port $vm.SSHPort -username $user -password $password -command "cat limits.conf >> /etc/security/limits.conf"

				LogMsg "Downlaoding LIS-RDMA drivers ..."
				$out = RunLinuxCmd -runAsSudo -ip $vm.PublicIP -port $vm.SSHPort -username $user -password $password -command "wget https://ciwestus.blob.core.windows.net/linuxbinaries/lis-4.0.11-RDMA.tar"

				LogMsg "Executing $LIS4IntallCommand ..."
				$jobID = RunLinuxCmd -runAsSudo -ip $vm.PublicIP -port $vm.SSHPort -username $user -password $password -command "$LIS4IntallCommand" -RunInBackground
				$LIS4InstallObj = New-Object PSObject
				Add-member -InputObject $LIS4InstallObj -MemberType NoteProperty -Name ID -Value $jobID
				Add-member -InputObject $LIS4InstallObj -MemberType NoteProperty -Name RoleName -Value $vm.RoleName
				Add-member -InputObject $LIS4InstallObj -MemberType NoteProperty -Name PublicIP -Value $vm.PublicIP
				Add-member -InputObject $LIS4InstallObj -MemberType NoteProperty -Name SSHPort -Value $vm.SSHPort
				$LIS4InstallJobs += $LIS4InstallObj
			}

			$LIS4InstallJobsRunning = $true
			$lisInstallErrorCount = 0
			while ($LIS4InstallJobsRunning)
			{
				$LIS4InstallJobsRunning = $false
				foreach ( $job in $LIS4InstallJobs )
				{
					if ( (Get-Job -Id $($job.ID)).State -eq "Running" )
					{
						LogMsg "LIS4-rdma Installation Status for $($job.RoleName) : Running"
						$LIS4InstallJobsRunning = $true
					}
					else
					{
						$jobOut = Receive-Job -ID $($job.ID) 
						if ( $jobOut -imatch "Please reboot your system")
						{
							LogMsg "LIS-rdma installed successfully for $($job.RoleName)"
						}
						else
						{
							#LogErr "LIS-rdma installation failed $($job.RoleName)"
							#$lisInstallErrorCount += 1
						}
					}

				}
				if ( $LIS4InstallJobsRunning )
				{
					WaitFor -seconds 10
				}
				#else
				#{
				#	if ( $lisInstallErrorCount -ne 0 )
				#	{
				#		Throw "LIS-rdma installation failed for some VMs.Aborting Test."
				#	}
				#}
			}
		
			$isRestarted = RestartAllDeployments -allVMData $allVMData
			if ( ! $isRestarted )
			{
				Throw "Failed to restart deployments in $isDeployed. Aborting Test."
			}
		}
		else
		{
			LogMsg "RDMA LIS Drivers are already installed."
			LogMsg $modinfo_hv_vmbus
			Add-Content -Value "rdmaPrepare=`"no`"" -Path $constantsFile
			LogMsg "rdmaPrepare=no added to constansts.sh"
		}
		#endregion

		RemoteCopy -uploadTo $serverVMData.PublicIP -port $serverVMData.SSHPort -files "$constantsFile" -username $user -password $password -upload
		$out = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "chmod +x *.sh"
		if ( $modinfo_hv_vmbus -imatch "microsoft-hyper-v-rdma" )
		{
			$testOut = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "/home/$user/StartRDMA.sh"
		}
		else
		{

            #$mpirunPath = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -command 'find / -name mpirun | grep intel64'
            #$imb_mpi1Path = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -command 'find / -name IMB-MPI1 | grep intel64'
            $pingPongTestIntraNodeTestOut = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "/opt/intel/impi/5.0.3.048/intel64/bin/mpirun -hosts server-vm -ppn 2 -n 2 -env I_MPI_FABRICS dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 /opt/intel/impi/5.0.3.048/intel64/bin/IMB-MPI1 pingpong > /home/$user/pingPongTestIntraNodeTestOut.txt 2>&1" -ignoreLinuxExitCode
			$pingPongTestInterNodeTestOut = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "/opt/intel/impi/5.0.3.048/intel64/bin/mpirun -hosts server-vm,client-vm -ppn 2 -n 4 -env I_MPI_FABRICS dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 /opt/intel/impi/5.0.3.048/intel64/bin/IMB-MPI1 pingpong > /home/$user/pingPongTestInterNodeTestOut.txt 2>&1" -ignoreLinuxExitCode
            #region EXECUTE TEST
			#$testJob = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "/home/$user/StartRDMA.sh" -RunInBackground
			##endregion#
#`
			#region MONITOR TEST
			#while ( (Get-Job -Id $testJob).State -eq "Running" )
			#{
		#		$currentStatus = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "tail -n 1 /home/$user/rdmaConsole.txt"
		#		LogMsg "Current Test Staus : $currentStatus"
	    #		WaitFor -seconds 10
		#	}
		}

		#RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "/home/$user/rdmaConsole.txt"
		#RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "/home/$user/summary.log"
		RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "/home/$user/pingPongTestIntraNodeTestOut.txt"
        RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "/home/$user/pingPongTestInterNodeTestOut.txt"

        RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "/var/log/waagent.log"
        $out= RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "dmesg > /var/log/dmesg.txt"
        RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "/var/log/dmesg.txt"

		$pingPongTestIntraNodeTestOut =  ( Get-Content -Path "$LogDir\pingPongTestIntraNodeTestOut.txt" | Out-String )
		LogMsg $pingPongTestIntraNodeTestOut
		LogMsg "PINGPONG INTER NODE TEST OUTPUT-"
		$pingPongTestInterNodeTestOut =  ( Get-Content -Path "$LogDir\pingPongTestInterNodeTestOut.txt" | Out-String )
		LogMsg $pingPongTestInterNodeTestOut
        if ($pingPongTestIntraNodeTestOut -imatch "4194304" -and $pingPongTestInterNodeTestOut-imatch "4194304" )
		{
            $finalStatus = "TestCompleted"
        }
        else
        {
            $finalStatus = "TestFailed"
        }		
        #$finalStatus = RunLinuxCmd -runAsSudo -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username $user -password $password -command "cat /home/$user/state.txt"
		#$rdmaSummary = Get-Content -Path "$LogDir\summary.log" -ErrorAction SilentlyContinue
		
		if ($finalStatus -imatch "TestCompleted")
		{
			LogMsg "Test finished successfully."
		}
		else
		{
			LogErr "Test did not finished successfully. Please check $LogDir\rdmaConsole.txt for detailed results."
		}
		#endregion


		if ( $finalStatus -imatch "TestFailed")
		{
			LogErr "Test failed. Last known status : $currentStatus."
			$testResult = "FAIL"
		}
		elseif ( $finalStatus -imatch "TestAborted")
		{
			LogErr "Test Aborted. Last known status : $currentStatus."
			$testResult = "ABORTED"
		}
		elseif ( $finalStatus -imatch "TestCompleted")
		{
			LogMsg "Test Completed. Result : $finalStatus."
			$testResult = "PASS"
		}
		elseif ( $finalStatus -imatch "TestRunning")
		{
			LogMsg "Powershell backgroud job for test is completed but VM is reporting that test is still running. Please check $LogDir\mdConsoleLogs.txt"
			LogMsg "Contests of state.txt : $finalStatus"
			$testResult = "PASS"
		}
		LogMsg "Test result : $testResult"
		LogMsg "Test Completed"
	
    }
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = "PingPong"
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
		$resultSummary +=  CreateResultSummary -testResult $finalStatus -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result, $resultSummary
