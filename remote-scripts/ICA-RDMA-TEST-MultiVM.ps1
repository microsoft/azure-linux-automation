#author - v-shisav@microsoft.com
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
if ($currentTestData.OverrideVMSize)
{
	Set-Variable -Name OverrideVMSize -Value $currentTestData.OverrideVMSize -Scope Global
}
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
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
				$clientMachines += $vmData
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
			Start-Sleep -Seconds 300
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
			$i += 1
		}
		$firstRun = $true
		#
		# PROVISION VMS FOR LISA WILL ENABLE ROOT USER AND WILL MAKE ENABLE PASSWORDLESS AUTHENTICATION ACROSS ALL VMS IN SAME HOSTED SERVICE.
		#

		ProvisionVMsForLisa -allVMData $allVMData -installPackagesOnRoleNames "none"

		#endregion

		#region Generate constants.sh

		LogMsg "Generating constansts.sh ..."
		$constantsFile = ".\$LogDir\constants.sh"
		foreach ($testParam in $currentTestData.params.param )
		{
			Add-Content -Value "$testParam" -Path $constantsFile
			LogMsg "$testParam added to constansts.sh"
			if ($testParam -imatch "imb_mpi1_tests_iterations")
			{
				$imb_mpi1_test_iterations = [int]($testParam.Replace("imb_mpi1_tests_iterations=",""))
			}
			if ($testParam -imatch "imb_rma_tests_iterations")
			{
				$imb_rma_tests_iterations = [int]($testParam.Replace("imb_rma_tests_iterations=",""))
			}
			if ($testParam -imatch "imb_nbc_tests_iterations")
			{
				$imb_nbc_tests_iterations = [int]($testParam.Replace("imb_nbc_tests_iterations=",""))
			}
		}

		Add-Content -Value "master=`"$($serverVMData.RoleName)`"" -Path $constantsFile
		LogMsg "master=$($serverVMData.RoleName) added to constansts.sh"


		Add-Content -Value "slaves=`"$slaveHostnames`"" -Path $constantsFile
		LogMsg "slaves=$slaveHostnames added to constansts.sh"

		LogMsg "constanst.sh created successfully..."
		#endregion

		#region Upload files to master VM...
		RemoteCopy -uploadTo $serverVMData.PublicIP -port $serverVMData.SSHPort -files "$constantsFile,.\remote-scripts\TestRDMA_MultiVM.sh" -username "root" -password $password -upload
		#endregion

		RemoteCopy -uploadTo $serverVMData.PublicIP -port $serverVMData.SSHPort -files "$constantsFile" -username "root" -password $password -upload
		$out = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -command "chmod +x *.sh"
		$remainingRebootIterations = $currentTestData.NumberOfReboots
		$ExpectedSuccessCount = [int]($currentTestData.NumberOfReboots) + 1
		$totalSuccessCount = 0
		$iteration = 0
		do
		{
			if ($firstRun)
			{
				$firstRun = $false
				$continueMPITest = $true
				foreach ( $clientVMData in $clientMachines )
				{
					LogMsg "Getting initial MAC address info from $($clientVMData.RoleName)"
					RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password "ifconfig eth1 | grep ether | awk '{print `$2}' > InitialInfiniBandMAC.txt"
				}
			}
			else
			{
				$continueMPITest = $true
				foreach ( $clientVMData in $clientMachines )
				{
					LogMsg "Step 1/2: Getting current MAC address info from $($clientVMData.RoleName)"
					$currentMAC = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password "ifconfig eth1 | grep ether | awk '{print `$2}'"
					$InitialMAC = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password "cat InitialInfiniBandMAC.txt"
					if ($currentMAC -eq $InitialMAC)
					{
						LogMsg "Step 2/2: MAC address verified in $($clientVMData.RoleName)."
					}
					else
					{
						LogErr "Step 2/2: MAC address swapped / changed in $($clientVMData.RoleName)."
						$continueMPITest = $false
					}
				}
			}

			if($continueMPITest)
			{
				#region EXECUTE TEST
				$iteration += 1
				LogMsg "********************************Iteration - $iteration/$ExpectedSuccessCount***********************************************"
				$testJob = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -command "/root/TestRDMA_MultiVM.sh" -RunInBackground
				#endregion

				#region MONITOR TEST
				while ( (Get-Job -Id $testJob).State -eq "Running" )
				{
					$currentStatus = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -command "tail -n 1 /root/TestRDMALogs.txt"
					LogMsg "Current Test Staus : $currentStatus"
					WaitFor -seconds 10
				}

				RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "/root/eth1-status*"
				RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "/root/IMB-*"
				RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "/root/kernel-logs-*"
				RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "/root/TestRDMALogs.txt"
				RemoteCopy -downloadFrom $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "/root/state.txt"
				$consoleOutput =  ( Get-Content -Path "$LogDir\TestRDMALogs.txt" | Out-String )
				$finalStatus = RunLinuxCmd -ip $serverVMData.PublicIP -port $serverVMData.SSHPort -username "root" -password $password -command "cat /root/state.txt"
				if($iteration -eq 1)
				{
					$tempName = "FirstBoot"
				}
				else
				{
					$tempName = "Reboot"
				}
				$out = mkdir -Path "$LogDir\InfiniBand-Verification-$iteration-$tempName" -Force | Out-Null
				$out = Move-Item -Path "$LogDir\eth1-status*" -Destination "$LogDir\InfiniBand-Verification-$iteration-$tempName" | Out-Null
				$out = Move-Item -Path "$LogDir\IMB-*" -Destination "$LogDir\InfiniBand-Verification-$iteration-$tempName" | Out-Null
				$out = Move-Item -Path "$LogDir\kernel-logs-*" -Destination "$LogDir\InfiniBand-Verification-$iteration-$tempName" | Out-Null
				$out = Move-Item -Path "$LogDir\TestRDMALogs.txt" -Destination "$LogDir\InfiniBand-Verification-$iteration-$tempName" | Out-Null
				$out = Move-Item -Path "$LogDir\state.txt" -Destination "$LogDir\InfiniBand-Verification-$iteration-$tempName" | Out-Null

				#region Check if eth1 got IP address
				$logFileName = "$LogDir\InfiniBand-Verification-$iteration-$tempName\TestRDMALogs.txt"
				$pattern = "INFINIBAND_VERIFICATION_SUCCESS_ETH1"
				LogMsg "Analysing $logFileName"
				$metaData = "InfiniBand-Verification-$iteration-$tempName : eth1 IP"
				$sucessLogs = Select-String -Path $logFileName -Pattern $pattern
				if ($sucessLogs.Count -eq 1)
				{
					$currentResult = "PASS"
				}
				else
				{
					$currentResult = "FAIL"
				}
				LogMsg "$pattern : $currentResult"
				$resultArr += $currentResult
				$resultSummary +=  CreateResultSummary -testResult $currentResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				#endregion

				#region Check MPI pingpong intranode tests
				$logFileName = "$LogDir\InfiniBand-Verification-$iteration-$tempName\TestRDMALogs.txt"
				$pattern = "INFINIBAND_VERIFICATION_SUCCESS_MPI1_INTRANODE"
				LogMsg "Analysing $logFileName"
				$metaData = "InfiniBand-Verification-$iteration-$tempName : PingPong Intranode"
				$sucessLogs = Select-String -Path $logFileName -Pattern $pattern
				if ($sucessLogs.Count -eq 1)
				{
					$currentResult = "PASS"
				}
				else
				{
					$currentResult = "FAIL"
				}
				LogMsg "$pattern : $currentResult"
				$resultArr += $currentResult
				$resultSummary +=  CreateResultSummary -testResult $currentResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				#endregion

				#region Check MPI pingpong internode tests
				$logFileName = "$LogDir\InfiniBand-Verification-$iteration-$tempName\TestRDMALogs.txt"
				$pattern = "INFINIBAND_VERIFICATION_SUCCESS_MPI1_INTERNODE"
				LogMsg "Analysing $logFileName"
				$metaData = "InfiniBand-Verification-$iteration-$tempName : PingPong Internode"
				$sucessLogs = Select-String -Path $logFileName -Pattern $pattern
				if ($sucessLogs.Count -eq 1)
				{
					$currentResult = "PASS"
				}
				else
				{
					$currentResult = "FAIL"
				}
				LogMsg "$pattern : $currentResult"
				$resultArr += $currentResult
				$resultSummary +=  CreateResultSummary -testResult $currentResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				#endregion

				#region Check MPI1 all nodes tests
				if ( $imb_mpi1_test_iterations -ge 1)
				{
					$logFileName = "$LogDir\InfiniBand-Verification-$iteration-$tempName\TestRDMALogs.txt"
					$pattern = "INFINIBAND_VERIFICATION_SUCCESS_MPI1_ALLNODES"
					LogMsg "Analysing $logFileName"
					$metaData = "InfiniBand-Verification-$iteration-$tempName : IMB-MPI1"
					$sucessLogs = Select-String -Path $logFileName -Pattern $pattern
					if ($sucessLogs.Count -eq 1)
					{
						$currentResult = "PASS"
					}
					else
					{
						$currentResult = "FAIL"
					}
					LogMsg "$pattern : $currentResult"
					$resultArr += $currentResult
					$resultSummary +=  CreateResultSummary -testResult $currentResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				}
				#endregion

				#region Check RMA all nodes tests
				if ( $imb_rma_tests_iterations -ge 1)
				{
					$logFileName = "$LogDir\InfiniBand-Verification-$iteration-$tempName\TestRDMALogs.txt"
					$pattern = "INFINIBAND_VERIFICATION_SUCCESS_RMA_ALLNODES"
					LogMsg "Analysing $logFileName"
					$metaData = "InfiniBand-Verification-$iteration-$tempName : IMB-RMA"
					$sucessLogs = Select-String -Path $logFileName -Pattern $pattern
					if ($sucessLogs.Count -eq 1)
					{
						$currentResult = "PASS"
					}
					else
					{
						$currentResult = "FAIL"
					}
					LogMsg "$pattern : $currentResult"
					$resultArr += $currentResult
					$resultSummary +=  CreateResultSummary -testResult $currentResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				}
				#endregion

				#region Check NBC all nodes tests
				if ( $imb_nbc_tests_iterations -ge 1)
				{
					$logFileName = "$LogDir\InfiniBand-Verification-$iteration-$tempName\TestRDMALogs.txt"
					$pattern = "INFINIBAND_VERIFICATION_SUCCESS_RMA_ALLNODES"
					LogMsg "Analysing $logFileName"
					$metaData = "InfiniBand-Verification-$iteration-$tempName : IMB-NBC"
					$sucessLogs = Select-String -Path $logFileName -Pattern $pattern
					if ($sucessLogs.Count -eq 1)
					{
						$currentResult = "PASS"
					}
					else
					{
						$currentResult = "FAIL"
					}
					LogMsg "$pattern : $currentResult"
					$resultArr += $currentResult
					$resultSummary +=  CreateResultSummary -testResult $currentResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				}
				#endregion

				if ($finalStatus -imatch "TestCompleted")
				{
					LogMsg "Test finished successfully."
					LogMsg $consoleOutput
				}
				else
				{
					LogErr "Test failed."
					LogErr $consoleOutput
				}
				#endregion


			}
			else
			{
				$finalStatus = "TestFailed"
			}

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
				$totalSuccessCount += 1
			}
			elseif ( $finalStatus -imatch "TestRunning")
			{
				LogMsg "Powershell backgroud job for test is completed but VM is reporting that test is still running. Please check $LogDir\mdConsoleLogs.txt"
				LogMsg "Contests of state.txt : $finalStatus"
				$testResult = "FAIL"
			}
			LogMsg "*********************************************************************************************"
			if ($remainingRebootIterations -gt 0)
			{
				if ($testResult -eq "PASS")
				{
					$RestartStatus = RestartAllDeployments -allVMData $allVMData
					$remainingRebootIterations -= 1
				}
				else
				{
					Write-Host "Stopping the test."
				}

			}

		}
		while(($ExpectedSuccessCount -ne $iteration) -and ($RestartStatus -eq "True") -and ($testResult -eq "PASS"))
		if ( $ExpectedSuccessCount -eq $totalSuccessCount )
		{
			$testResult = "PASS"
		}
		else
		{
			$testResult = "FAIL"
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
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
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
