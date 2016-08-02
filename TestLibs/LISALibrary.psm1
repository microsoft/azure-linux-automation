#
# This function enables the root password and ssh key based authentication across all VMs in same service / resource group.
# $allVMData : PSObject which contains all the VM data in same service / resource group.
# $installPackagesOnRoleName : [string] if you want to install packages on specific role only then use this parameter. Eg. ProvisionVMsForLisa -allVMData $VMData -installPackagesOnRoleName "master"
#    Multiple Rolenames can be given as "master,client"
#
Function ProvisionVMsForLisa($allVMData, $installPackagesOnRoleNames)
{
	$scriptUrl = "https://raw.githubusercontent.com/iamshital/lis-test/master/WS2012R2/lisa/remote-scripts/ica/provisionLinuxForLisa.sh"
	$sshPrivateKeyPath = ".\ssh\myPrivateKey.key"
	$sshPrivateKey = "myPrivateKey.key"
	LogMsg "Downloading $scriptUrl ..."
	$scriptName =  $scriptUrl.Split("/")[$scriptUrl.Split("/").Count-1]
	$start_time = Get-Date
	$out = Invoke-WebRequest -Uri $scriptUrl -OutFile "$LogDir\$scriptName"
	LogMsg "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    $keysGenerated = $false
	foreach ( $vmData in $allVMData )
	{
		LogMsg "Configuring $($vmData.RoleName) for LISA test..."
		RemoteCopy -uploadTo $vmData.PublicIP -port $vmData.SSHPort -files ".\remote-scripts\enableRoot.sh,.\remote-scripts\enablePasswordLessRoot.sh,.\$LogDir\provisionLinuxForLisa.sh" -username $user -password $password -upload
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "chmod +x /home/$user/*.sh" -runAsSudo			
		$rootPasswordSet = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "/home/$user/enableRoot.sh -password $($password.Replace('"',''))" -runAsSudo
		LogMsg $rootPasswordSet
		if (( $rootPasswordSet -imatch "ROOT_PASSWRD_SET" ) -and ( $rootPasswordSet -imatch "SSHD_RESTART_SUCCESSFUL" ))
		{
			LogMsg "root user enabled for $($vmData.RoleName) and password set to $password"
		}
		else
		{
			Throw "Failed to enable root password / starting SSHD service. Please check logs. Aborting test."
		}
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "cp -ar /home/$user/*.sh ."
        if ( $keysGenerated )
        {
            RemoteCopy -uploadTo $vmData.PublicIP -port $vmData.SSHPort -files ".\$LogDir\sshFix.tar" -username "root" -password $password -upload
            $keyCopyOut = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "./enablePasswordLessRoot.sh" 
            LogMsg $keyCopyOut
            if ( $keyCopyOut -imatch "KEY_COPIED_SUCCESSFULLY" )
            {
                $keysGenerated = $true
                LogMsg "SSH keys copied to $($vmData.RoleName)"
                $md5sumCopy = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "md5sum .ssh/id_rsa"
                if ( $md5sumGen -eq $md5sumCopy )
                { 
		            LogMsg "md5sum check success for .ssh/id_rsa."
                }
                else
                {
                    Throw "md5sum check failed for .ssh/id_rsa. Aborting test."
                }
            }
            else
            {
                Throw "Error in copying SSH key to $($vmData.RoleName)"
            }
        }
        else
        {
            $out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "rm -rf /root/sshFix*" 
            $keyGenOut = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "./enablePasswordLessRoot.sh" 
            LogMsg $keyGenOut
            if ( $keyGenOut -imatch "KEY_GENERATED_SUCCESSFULLY" )
            {
                $keysGenerated = $true
                LogMsg "SSH keys generated in $($vmData.RoleName)"
                RemoteCopy -download -downloadFrom $vmData.PublicIP -port $vmData.SSHPort  -files "/root/sshFix.tar" -username "root" -password $password -downloadTo $LogDir
                $md5sumGen = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "md5sum .ssh/id_rsa"
            }
            else
            {
                Throw "Error in generating SSH key in $($vmData.RoleName)"
            }
        }

	}
	
	$packageInstallJobs = @()
	foreach ( $vmData in $allVMData )
	{
		if ( $installPackagesOnRoleNames )
		{
			if ( $installPackagesOnRoleNames -imatch $vmData.RoleName )
			{
				LogMsg "Executing $scriptName ..."
				$jobID = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "/root/$scriptName" -RunInBackground
				$packageInstallObj = New-Object PSObject
				Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name ID -Value $jobID
				Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name RoleName -Value $vmData.RoleName
				Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name PublicIP -Value $vmData.PublicIP
				Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name SSHPort -Value $vmData.SSHPort
				$packageInstallJobs += $packageInstallObj
				#endregion
			}
			else
			{
				LogMsg "$($vmData.RoleName) is set to NOT install packages. Hence skipping package installation on this VM."
			}
		}
		else
		{
			LogMsg "Executing $scriptName ..."
			$jobID = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "/root/$scriptName" -RunInBackground
			$packageInstallObj = New-Object PSObject
			Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name ID -Value $jobID
			Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name RoleName -Value $vmData.RoleName
			Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name PublicIP -Value $vmData.PublicIP
			Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name SSHPort -Value $vmData.SSHPort
			$packageInstallJobs += $packageInstallObj
			#endregion
		}		
	}
	
	$packageInstallJobsRunning = $true
	while ($packageInstallJobsRunning)
	{
		$packageInstallJobsRunning = $false
		foreach ( $job in $packageInstallJobs )
		{
			if ( (Get-Job -Id $($job.ID)).State -eq "Running" )
			{
				$currentStatus = RunLinuxCmd -ip $job.PublicIP -port $job.SSHPort -username "root" -password $password -command "tail -n 1 /root/provisionLinux.log"
				LogMsg "Package Installation Status for $($job.RoleName) : $currentStatus"
				$packageInstallJobsRunning = $true
			}
			else
			{
				RemoteCopy -download -downloadFrom $job.PublicIP -port $job.SSHPort -files "/root/provisionLinux.log" -username "root" -password $password -downloadTo $LogDir
				Rename-Item -Path "$LogDir\provisionLinux.log" -NewName "$($job.RoleName)-provisionLinux.log" -Force | Out-Null
			}
		}
		if ( $packageInstallJobsRunning )
		{
			WaitFor -seconds 10
		}
	}
}

function InstallCustomKernel ($customKernel, $allVMData, [switch]$RestartAfterUpgrade)
{
    try
    {
        $customKernel = $customKernel.Trim()
        if( ($customKernel -ne "linuxnext") -and ($customKernel -ne "netnext") )
        {
            LogErr "Only linuxnext and netnext version is supported. Other version will be added soon. Use -customKernel linuxnext"
        }
        else
        {
            $scriptName = "customKernelInstall.sh"
            $jobCount = 0
            $kernelSuccess = 0
	        $packageInstallJobs = @()
	        foreach ( $vmData in $allVMData )
	        {
                RemoteCopy -uploadTo $vmData.PublicIP -port $vmData.SSHPort -files ".\remote-scripts\$scriptName,.\SetupScripts\DetectLinuxDistro.sh" -username $user -password $password -upload
                $out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "chmod +x *.sh" -runAsSudo
                $currentKernelVersion = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "uname -r"
		        LogMsg "Executing $scriptName ..."
		        $jobID = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "/home/$user/$scriptName -customKernel $customKernel" -RunInBackground -runAsSudo
		        $packageInstallObj = New-Object PSObject
		        Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name ID -Value $jobID
		        Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name RoleName -Value $vmData.RoleName
		        Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name PublicIP -Value $vmData.PublicIP
		        Add-member -InputObject $packageInstallObj -MemberType NoteProperty -Name SSHPort -Value $vmData.SSHPort
		        $packageInstallJobs += $packageInstallObj
                $jobCount += 1
		        #endregion
	        }
	
	        $packageInstallJobsRunning = $true
	        while ($packageInstallJobsRunning)
	        {
		        $packageInstallJobsRunning = $false
		        foreach ( $job in $packageInstallJobs )
		        {
			        if ( (Get-Job -Id $($job.ID)).State -eq "Running" )
			        {
				        $currentStatus = RunLinuxCmd -ip $job.PublicIP -port $job.SSHPort -username $user -password $password -command "tail -n 1 build-customKernel.txt"
				        LogMsg "Package Installation Status for $($job.RoleName) : $currentStatus"
				        $packageInstallJobsRunning = $true
			        }
			        else
			        {
                        if ( !(Test-Path -Path "$LogDir\$($job.RoleName)-build-customKernel.txt" ) )
                        {
				            RemoteCopy -download -downloadFrom $job.PublicIP -port $job.SSHPort -files "build-customKernel.txt" -username $user -password $password -downloadTo $LogDir
                            if ( ( Get-Content "$LogDir\build-customKernel.txt" ) -imatch "CUSTOM_KERNEL_SUCCESS" )
                            {
                                $kernelSuccess += 1
                            }
				            Rename-Item -Path "$LogDir\build-customKernel.txt" -NewName "$($job.RoleName)-build-customKernel.txt" -Force | Out-Null
                        }
			        }
		        }
		        if ( $packageInstallJobsRunning )
		        {
			        WaitFor -seconds 10
		        }
	        }
    
            if ( $kernelSuccess -eq $jobCount )
            {
                LogMsg "Kernel upgraded to `"$customKernel`" successfully in all VMs."
                if ( $RestartAfterUpgrade )
                {
                    LogMsg "Now restarting VMs..."
                    $restartStatus = RestartAllDeployments -allVMData $allVMData
                    if ( $restartStatus -eq "True")
                    {
                        $upgradedKernelVersion = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "uname -r"
                        LogMsg "Old kernel: $currentKernelVersion"
                        LogMsg "New kernel: $upgradedKernelVersion"
                        Add-Content -Value "Old kernel: $currentKernelVersion" -Path .\report\AdditionalInfo.html -Force
                        Add-Content -Value "New kernel: $upgradedKernelVersion" -Path .\report\AdditionalInfo.html -Force
                        return $true
                    }
                    else
                    {
                        return $false
                    }
                }
                return $true
            }
            else
            {
                LogErr "Kernel upgrade failed in $($jobCount-$kernelSuccess) VMs."
                return $false
            }
        }
    }
    catch
    {
        LogErr "Exception in InstallCustomKernel."
        return $false
    }
}