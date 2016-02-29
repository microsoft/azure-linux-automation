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

	Set-Content -Value "echo `"Host *`" > /home/$user/.ssh/config" -Path "$LogDir\disableHostKeyVerification.sh"
	Add-Content -Value "echo StrictHostKeyChecking=no >> /home/$user/.ssh/config" -Path "$LogDir\disableHostKeyVerification.sh"
	Add-Content -Value "echo IdentityFile /root/$sshPrivateKey >> /home/$user/.ssh/config" -Path "$LogDir\disableHostKeyVerification.sh"

	foreach ( $vmData in $allVMData )
	{
		LogMsg "Configuring $($vmData.RoleName) for LISA test..."
		RemoteCopy -uploadTo $vmData.PublicIP -port $vmData.SSHPort -files ".\remote-scripts\enableRoot.sh,$sshPrivateKeyPath,.\$LogDir\disableHostKeyVerification.sh,.\$LogDir\provisionLinuxForLisa.sh" -username $user -password $password -upload
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
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "chmod 600 /home/$user/$sshPrivateKey && cp -ar /home/$user/* /root/"
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "mkdir -p /root/.ssh/ && cp /home/$user/.ssh/authorized_keys /root/.ssh/" 
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "/home/$user/disableHostKeyVerification.sh" 
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "cp /home/$user/.ssh/config /root/.ssh/" 
		$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username "root" -password $password -command "service sshd restart" 
		LogMsg "$($vmData.RoleName) preparation finished."
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