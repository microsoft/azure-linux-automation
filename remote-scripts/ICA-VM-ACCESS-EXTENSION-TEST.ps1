<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

$extnXML = [xml](Get-Content .\XML\Extensions.xml)
foreach ($extn in $extnXML.Extensions.Extension) 
{ 
	if($extn.Name -imatch "VMAccess")
	{
		$MyExtn = $extn
	}
}

$NewUser = $MyExtn.PrivateConfiguration.username
$passwd = $MyExtn.PrivateConfiguration.password
$newpassword = $MyExtn.NewPassword
$expiration = $MyExtn.PrivateConfiguration.Expiration
$ExtensionName = $MyExtn.OfficialName
$Publisher = $MyExtn.Publisher
$ExtVersion =  $MyExtn.Version
$ExtVersionForARM = $MyExtn.LatestVersion

Function VerfiyAddUserScenario ($vmData, $PublicConfigString, $PrivateConfigString, $metaData)
{
		$ExitCode = "ABORTED"
		$errorCount = 0
		LogMsg "Starting scenario $metaData"
		$statusFileToVerify = GetStatusFileNameToVerfiy -vmData $vmData -expectedExtensionName $ExtensionName -upcoming
		$isExtensionEnabled = SetAzureVMExtension -publicConfigString $PublicConfigString -privateConfigString $PrivateConfigString -ExtensionName $ExtensionName -ExtensionVersion $ExtVersion -LatestExtensionVersion $ExtVersionForARM -Publisher $Publisher -vmData $vmData
		if ($isExtensionEnabled)
		{
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFile : START ---------------------"
			$statusFilePath = GetFilePathsFromLinuxFolder -folderToSearch "/var/lib/waagent" -IpAddress $allVMData.PublicIP -SSHPort $allVMData.SSHPort -username $user -password $password -expectedFiles $statusFileToVerify

			if ( $statusFilePath[0] )
			{
				$ExtensionStatusInStatusFile = GetExtensionStatusFromStatusFile -statusFilePaths $statusFilePath[0] -ExtensionName $ExtensionName -vmData $vmData
			}
			else
			{
				LogErr "status file not found under /var/lib/waagent"
				$ExtensionStatusInStatusFile = $false
			}
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFile : END ---------------------"
			#endregion

			#region check Extension from Azure Side
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : START ---------------------"
			$ExtensionStatusFromAzure = VerifyExtensionFromAzure -ExtensionName $ExtensionName -ServiceName $isDeployed -ResourceGroupName $isDeployed
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : END ---------------------"
			#endregion

			#region check if extension has done its job properply...
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : START ---------------------"
			$folderToSearch = "/var/log/azure"
			$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $vmData.PublicIP -SSHPort $vmData.SSHPort -username $user -password $password -expectedFiles "extension.log,CommandExecution.log"
			$LogFilesPaths = $FoundFiles[0]
			$LogFiles = $FoundFiles[1]
			$retryCount = 1
			$maxRetryCount = 10
			if ($LogFilesPaths)
			{   
				do
				{
					LogMsg "Attempt : $retryCount/$maxRetryCount : Verifying $metaData scenario in the VM...."
					#Verify log file contents.
					DownloadExtensionLogFilesFromVarLog -LogFilesPaths $LogFilesPaths -ExtensionName $ExtensionName -vmData $vmData
					Rename-Item -Path "$LogDir\extension.log" -NewName "extension.log.$metaData.txt" -Force | Out-Null
					$extensionLog = [string]( Get-Content "$LogDir\extension.log.$metaData.txt" )

					if ( $extensionLog  -imatch "Succeeded in create the account" )
					{
						LogMsg "extesnsion.log reported Succeeded in create the account."
					}
					else
					{
						LogErr "extesnsion.log NOT reported Succeeded in create the account."
						$errorCount += 1
					}

					try
					{
						#Verfiy command execution without sudo ...
						$testOut1 = RunLinuxCmd -username $NewUser -password $passwd -ip $vmData.PublicIP -port $vmData.SSHPort -command "uname -a"
						LogMsg $testOut1 -LinuxConsoleOuput
						LogMsg "NEW USER : $NewUser : command execution without sudo, verified."

						#Verify command execution with sudo ...
						$testOut2 = RunLinuxCmd -username $NewUser -password $passwd -ip $vmData.PublicIP -port $vmData.SSHPort -command "uname -a" -runAsSudo
						LogMsg $testOut1 -LinuxConsoleOuput
						LogMsg "NEW USER : $NewUser : command execution with sudo, verified."
					}
					catch
					{
						$errorCount += 1
					}
					if ($errorCount -eq 0)
					{
						$extensionExecutionVerified = $true
						$waitForExtension = $false
						LogMsg "$metaData scenario verified successfully."
					}
					else
					{
						$extensionExecutionVerified  = $false
						LogErr "$metaData scenario failed."
						$waitForExtension = $true
						WaitFor -Seconds 30
					}
					$retryCount += 1
				}
				while (($retryCount -le $maxRetryCount) -and $waitForExtension )
			}
			else
			{
				LogErr "No Extension logs are available."
				$extensionExecutionVerified  = $false
			}
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : END ---------------------"
			#endregion

			if ( $ExtensionStatusFromAzure -and $extensionExecutionVerified  -and $ExtensionStatusInStatusFile )
			{
				LogMsg "STATUS FILE VERIFICATION : PASS"
				LogMsg "AZURE STATUS VERIFICATION : PASS"
				LogMsg "EXTENSION EXECUTION VERIFICATION : PASS"
				$ExitCode = "PASS"
			}
			else
			{
				if ( !$ExtensionStatusInStatusFile )
				{
					LogErr "STATUS FILE VERIFICATION : FAIL"
				}
				if ( !$ExtensionStatusFromAzure )
				{
					LogErr "AZURE STATUS VERIFICATION : FAIL"
				}
				if ( !$extensionExecutionVerified )
				{
					LogErr "EXTENSION EXECUTION VERIFICATION : FAIL"
				}
				$ExitCode = "FAIL"
			}
			LogMsg "$metaData result : $ExitCode"
		}
		else
		{
			LogErr "Failed to enable $ExtensionName"
			$ExitCode = "FAIL"
		}
return $ExitCode
}

Function VerfiyResetPasswordScenario ($vmData, $PublicConfigString, $PrivateConfigString, $metaData, $PrevTestStatus)
{
	$errorCount = 0
	if ( $PrevTestStatus -eq "PASS" )
	{
		$ExitCode = "ABORTED"
		$errorCount = 0
		LogMsg "Starting scenario $metaData"
		$statusFileToVerify = GetStatusFileNameToVerfiy -vmData $vmData -expectedExtensionName $ExtensionName -upcoming
		$isExtensionEnabled = SetAzureVMExtension -publicConfigString $PublicConfigString -privateConfigString $PrivateConfigString -ExtensionName $ExtensionName -ExtensionVersion $ExtVersion -LatestExtensionVersion $ExtVersionForARM -vmData $vmData -Publisher $Publisher
		if ($isExtensionEnabled)
		{
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFileToVerify : START ---------------------"
			$statusFilePath = GetFilePathsFromLinuxFolder -folderToSearch "/var/lib/waagent" -IpAddress $allVMData.PublicIP -SSHPort $allVMData.SSHPort -username $user -password $password -expectedFiles $statusFileToVerify

			if ( $statusFilePath[0] )
			{
				$ExtensionStatusInStatusFile = GetExtensionStatusFromStatusFile -statusFilePaths $statusFilePath[0] -ExtensionName $ExtensionName -vmData $vmData
			}
			else
			{
				LogErr "status file not found under /var/lib/waagent"
				$ExtensionStatusInStatusFile = $false
			}
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFileToVerify : END ---------------------"
			#endregion

			#region check Extension from Azure Side
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : START ---------------------"
			$ExtensionStatusFromAzure = VerifyExtensionFromAzure -ExtensionName $ExtensionName -ServiceName $isDeployed -ResourceGroupName $isDeployed
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : END ---------------------"
			#endregion

			#region check if extension has done its job properply...
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : START ---------------------"
			$folderToSearch = "/var/log/azure"
			$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $vmData.PublicIP -SSHPort $vmData.SSHPort -username $user -password $password -expectedFiles "extension.log,CommandExecution.log"
			$LogFilesPaths = $FoundFiles[0]
			$LogFiles = $FoundFiles[1]
			$retryCount = 1
			$maxRetryCount = 10
			if ($LogFilesPaths)
			{   
				do
				{
					LogMsg "Attempt : $retryCount/$maxRetryCount : Verifying $metaData scenario in the VM...."
					#Verify log file contents.
					DownloadExtensionLogFilesFromVarLog -LogFilesPaths $LogFilesPaths -ExtensionName $ExtensionName -vmData $vmData
					Rename-Item -Path "$LogDir\extension.log" -NewName "extension.log.$metaData.txt" -Force | Out-Null
					$extensionLog = [string]( Get-Content "$LogDir\extension.log.$metaData.txt" )

					if (( $extensionLog  -imatch "Will update password" ) -and ( $extensionLog  -imatch "Succeeded in create the account or set the password" ))
					{
						LogMsg "extesnsion.log reported Succeeded in reset password."
					}
					else
					{
						LogErr "extesnsion.log NOT reported Succeeded in reset password."
						$errorCount += 1
					}

					try
					{
						#Verfiy command execution without sudo ...
						$testOut1 = RunLinuxCmd -username $NewUser -password $newpassword -ip $vmData.PublicIP -port $vmData.SSHPort -command "uname -a"
						LogMsg $testOut1 -LinuxConsoleOuput
						LogMsg "NEW USER RESET PASSWORD : $NewUser : command execution without sudo, verified."

						#Verify command execution with sudo ...
						$testOut2 = RunLinuxCmd -username $NewUser -password $newpassword -ip $vmData.PublicIP -port $vmData.SSHPort -command "uname -a" -runAsSudo
						LogMsg $testOut1 -LinuxConsoleOuput
						LogMsg "NEW USER RESET PASSWORD : $NewUser : command execution with sudo, verified."
					}
					catch
					{
						$errorCount += 1
					}
					if ($errorCount -eq 0)
					{
						$extensionExecutionVerified = $true
						$waitForExtension = $false
						LogMsg "$metaData scenario verified successfully."
					}
					else
					{
						$extensionExecutionVerified  = $false
						LogErr "$metaData scenario failed."
						$waitForExtension = $true
						WaitFor -Seconds 30
					}
					$retryCount += 1
				}
				while (($retryCount -le $maxRetryCount) -and $waitForExtension )
			}
			else
			{
				LogErr "No Extension logs are available."
				$extensionExecutionVerified  = $false
			}
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : END ---------------------"
			#endregion

			if ( $ExtensionStatusFromAzure -and $extensionExecutionVerified  -and $ExtensionStatusInStatusFile )
			{
				LogMsg "STATUS FILE VERIFICATION : PASS"
				LogMsg "AZURE STATUS VERIFICATION : PASS"
				LogMsg "EXTENSION EXECUTION VERIFICATION : PASS"
				$ExitCode = "PASS"
			}
			else
			{
				if ( !$ExtensionStatusInStatusFile )
				{
					LogErr "STATUS FILE VERIFICATION : FAIL"
				}
				if ( !$ExtensionStatusFromAzure )
				{
					LogErr "AZURE STATUS VERIFICATION : FAIL"
				}
				if ( !$extensionExecutionVerified )
				{
					LogErr "EXTENSION EXECUTION VERIFICATION : FAIL"
				}
				$ExitCode = "FAIL"
			}
			LogMsg "$metaData result : $ExitCode"
		}
		else
		{
			LogErr "Failed to enable $ExtensionName"
			$ExitCode = "FAIL"
		}

	}
	elseif ( $PrevTestStatus -imatch "FAIL" )
	{
		$ExitCode = "ABORTED"
		LogMsg "Skipping TEST : $metaData due to previous failed test"
	}
	elseif ( $PrevTestStatus -imatch "ABORTED" )
	{
		$ExitCode = "ABORTED"
		LogMsg "Skipping TEST : $metaData due to previous Aborted test"
	}
return $ExitCode
}

Function VerfiyDeleteUserScenario ($vmData, $PublicConfigString, $PrivateConfigString, $metaData, $PrevTestStatus)
{
	$errorCount = 0
	if ( $PrevTestStatus -eq "PASS" )
	{
		$ExitCode = "ABORTED"
		$errorCount = 0
		LogMsg "Starting scenario $metaData"
		$statusFileToVerify = GetStatusFileNameToVerfiy -vmData $vmData -expectedExtensionName $ExtensionName -upcoming
		LogMsg "Getting contents of /etc/shadow"
		$out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "cat /etc/shadow > /home/$user/etcShadowFileBeforeDeleteUser.txt" -runAsSudo
		RemoteCopy -downloadFrom $vmData.PublicIP -port $vmData.SSHPort -downloadTo $LogDir -files "/home/$user/etcShadowFileBeforeDeleteUser.txt" -username $user -password $password -download
		$etcShadowFileBeforeDeleteUser = [string](Get-Content "$LogDir\etcShadowFileBeforeDeleteUser.txt")

		$isExtensionEnabled = SetAzureVMExtension -publicConfigString $PublicConfigString -privateConfigString $PrivateConfigString -ExtensionName $ExtensionName -ExtensionVersion $ExtVersion -LatestExtensionVersion $ExtVersionForARM -vmData $vmData -Publisher $Publisher
		if ($isExtensionEnabled)
		{
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFileToVerify : START ---------------------"
			$statusFilePath = GetFilePathsFromLinuxFolder -folderToSearch "/var/lib/waagent" -IpAddress $allVMData.PublicIP -SSHPort $allVMData.SSHPort -username $user -password $password -expectedFiles $statusFileToVerify

			if ( $statusFilePath[0] )
			{
				$ExtensionStatusInStatusFile = GetExtensionStatusFromStatusFile -statusFilePaths $statusFilePath[0] -ExtensionName $ExtensionName -vmData $vmData
			}
			else
			{
				LogErr "status file not found under /var/lib/waagent"
				$ExtensionStatusInStatusFile = $false
			}
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFileToVerify : END ---------------------"
			#endregion

			#region check Extension from Azure Side
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : START ---------------------"
			$ExtensionStatusFromAzure = VerifyExtensionFromAzure -ExtensionName $ExtensionName -ServiceName $isDeployed -ResourceGroupName $isDeployed
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : END ---------------------"
			#endregion

			#region check if extension has done its job properply...
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : START ---------------------"
			$folderToSearch = "/var/log/azure"
			$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $vmData.PublicIP -SSHPort $vmData.SSHPort -username $user -password $password -expectedFiles "extension.log,CommandExecution.log"
			$LogFilesPaths = $FoundFiles[0]
			$LogFiles = $FoundFiles[1]
			$retryCount = 1
			$maxRetryCount = 10
			if ($LogFilesPaths)
			{   
				do
				{
					LogMsg "Attempt : $retryCount/$maxRetryCount : Verifying $metaData scenario in the VM...."

					#Verify log file contents.

					DownloadExtensionLogFilesFromVarLog -LogFilesPaths $LogFilesPaths -ExtensionName $ExtensionName -vmData $vmData
					Rename-Item -Path "$LogDir\extension.log" -NewName "extension.log.$metaData.txt" -Force | Out-Null
					$extensionLog = [string]( Get-Content "$LogDir\extension.log.$metaData.txt" )

					LogMsg "Getting contents of /etc/shadow"
					$out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "cat /etc/shadow > /home/$user/etcShadowFileAfterDeleteUser.txt" -runAsSudo
					RemoteCopy -downloadFrom $vmData.PublicIP -port $vmData.SSHPort -downloadTo $LogDir -files "/home/$user/etcShadowFileAfterDeleteUser.txt" -username $user -password $password -download
					$etcShadowFileAfterDeleteUser = [string](Get-Content "$LogDir\etcShadowFileAfterDeleteUser.txt")
					if ( $etcShadowFileAfterDeleteUser -imatch "$NewUser`:")
					{
						LogErr "NEW USER : $NewUser NOT deleted from /etc/shadow file."
						$errorCount += 1
					}
					else
					{
						LogMsg "NEW USER : $NewUser has been deleted from /etc/shadow file."
					}
					if ($errorCount -eq 0)
					{
						$extensionExecutionVerified = $true
						$waitForExtension = $false
						LogMsg "$metaData scenario verified successfully."
					}
					else
					{
						$extensionExecutionVerified  = $false
						LogErr "$metaData scenario failed."
						$waitForExtension = $true
						WaitFor -Seconds 30
					}
					$retryCount += 1
				}
				while (($retryCount -le $maxRetryCount) -and $waitForExtension )
			}
			else
			{
				LogErr "No Extension logs are available."
				$extensionExecutionVerified  = $false
			}
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : END ---------------------"
			#endregion

			if ( $ExtensionStatusFromAzure -and $extensionExecutionVerified  -and $ExtensionStatusInStatusFile )
			{
				LogMsg "STATUS FILE VERIFICATION : PASS"
				LogMsg "AZURE STATUS VERIFICATION : PASS"
				LogMsg "EXTENSION EXECUTION VERIFICATION : PASS"
				$ExitCode = "PASS"
			}
			else
			{
				if ( !$ExtensionStatusInStatusFile )
				{
					LogErr "STATUS FILE VERIFICATION : FAIL"
				}
				if ( !$ExtensionStatusFromAzure )
				{
					LogErr "AZURE STATUS VERIFICATION : FAIL"
				}
				if ( !$extensionExecutionVerified )
				{
					LogErr "EXTENSION EXECUTION VERIFICATION : FAIL"
				}
				$ExitCode = "FAIL"
			}
			LogMsg "$metaData result : $ExitCode"
		}
		else
		{
			LogErr "Failed to enable $ExtensionName"
			$ExitCode = "FAIL"
		}

	}
	elseif ( $PrevTestStatus -imatch "FAIL" )
	{
		$ExitCode = "ABORTED"
		LogMsg "Skipping TEST : $metaData due to previous failed test"
	}
	elseif ( $PrevTestStatus -imatch "ABORTED" )
	{
		$ExitCode = "ABORTED"
		LogMsg "Skipping TEST : $metaData due to previous Aborted test"
	}
return $ExitCode
}

Function VerfiyResetSSHConfigScenario ($vmData, $PublicConfigString, $PrivateConfigString, $metaData)
{
		$errorCount = 0
		
		$ExitCode = "ABORTED"
		LogMsg "Starting scenario $metaData"
		$statusFileToVerify = GetStatusFileNameToVerfiy -vmData $vmData -expectedExtensionName $ExtensionName -upcoming
		$sshdConfigFilePath = "/etc/ssh/sshd_config"
		LogMsg "Taking backup of $sshdConfigFilePath"
		$out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "cp -a $sshdConfigFilePath /home/$user/sshd_config.bak" -runAsSudo
		#
		# Edit the "/etc/ssh/sshd_config" but DONT RES
		#
		$out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "sed --in-place -e 's`/Port 22\s`*`/Port 99/g' $sshdConfigFilePath" -runAsSudo 
		LogMsg "Replaced Port 22 > Port 99 in $sshdConfigFilePath"
		LogMsg "Resetting $sshdConfigFilePath using $ExtensionName..."

		$isExtensionEnabled = SetAzureVMExtension -publicConfigString $PublicConfigString -privateConfigString $PrivateConfigString -ExtensionName $ExtensionName -ExtensionVersion $ExtVersion -LatestExtensionVersion $ExtVersionForARM -vmData $vmData -Publisher $Publisher

		if ($isExtensionEnabled)
		{
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFileToVerify : START ---------------------"
			$statusFilePath = GetFilePathsFromLinuxFolder -folderToSearch "/var/lib/waagent" -IpAddress $allVMData.PublicIP -SSHPort $allVMData.SSHPort -username $user -password $password -expectedFiles $statusFileToVerify

			if ( $statusFilePath[0] )
			{
				$ExtensionStatusInStatusFile = GetExtensionStatusFromStatusFile -statusFilePaths $statusFilePath[0] -ExtensionName $ExtensionName -vmData $vmData
			}
			else
			{
				LogErr "status file not found under /var/lib/waagent"
				$ExtensionStatusInStatusFile = $false
			}
			LogMsg "--------------------- STAGE 1/3 : verification of $statusFileToVerify : END ---------------------"
			#endregion

			#region check Extension from Azure Side
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : START ---------------------"
			$ExtensionStatusFromAzure = VerifyExtensionFromAzure -ExtensionName $ExtensionName -ServiceName $isDeployed -ResourceGroupName $isDeployed
			LogMsg "--------------------- STAGE 2/3 : verification from Azure : END ---------------------"
			#endregion

			#region check if extension has done its job properply...
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : START ---------------------"
			$folderToSearch = "/var/log/azure"
			$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $vmData.PublicIP -SSHPort $vmData.SSHPort -username $user -password $password -expectedFiles "extension.log,CommandExecution.log"
			$LogFilesPaths = $FoundFiles[0]
			$LogFiles = $FoundFiles[1]
			$retryCount = 1
			$maxRetryCount = 10
			if ($LogFilesPaths)
			{   
				do
				{
					LogMsg "Attempt : $retryCount/$maxRetryCount : Verifying $metaData scenario in the VM...."
					#Verify log file contents.
					LogMsg "Getting contents of $sshdConfigFilePath"
					$out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "cat $sshdConfigFilePath > /home/$user/sshd_config.txt" -runAsSudo
					RemoteCopy -downloadFrom $vmData.PublicIP -port $vmData.SSHPort -downloadTo $LogDir -files "/home/$user/sshd_config.txt" -username $user -password $password -download
					$sshd_configFile = [string](Get-Content "$LogDir\sshd_config.txt")

					#Verify log file contents.
					DownloadExtensionLogFilesFromVarLog -LogFilesPaths $LogFilesPaths -ExtensionName $ExtensionName -vmData $vmData
					Remove-Item -Path "$LogDir\extension.log.$metaData.txt" -Force -ErrorAction SilentlyContinue
					Rename-Item -Path "$LogDir\extension.log" -NewName "extension.log.$metaData.txt" -Force | Out-Null
					$extensionLog = [string]( Get-Content "$LogDir\extension.log.$metaData.txt" )
					if  ( $extensionLog -imatch "Succeeded in reset sshd_config" )
					{
						LogMsg "extesnsion.log reported Succeeded in reset sshd_config."
					}
					else
					{
						LogErr "extesnsion.log NOT reported Succeeded in reset sshd_config."
						$errorCount += 1
					}

					if ( $sshd_configFile -imatch "Port 22")
					{
						LogMsg "$sshdConfigFilePath resetted successfully."
					}
					else
					{
						LogErr "$sshdConfigFilePath NOT resetted successfully. Reverting changes manually..."
						$errorCount += 1
						$out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "cp -a /home/$user/sshd_config.bak $sshdConfigFilePath" -runAsSudo
					}
					if ($errorCount -eq 0)
					{
						$extensionExecutionVerified = $true
						$waitForExtension = $false
						LogMsg "$metaData scenario verified successfully."
					}
					else
					{
						$extensionExecutionVerified  = $false
						LogErr "$metaData scenario failed."
						$waitForExtension = $true
						WaitFor -Seconds 30
					}
					$retryCount += 1
				}
				while (($retryCount -le $maxRetryCount) -and $waitForExtension )
			}
			else
			{
				LogErr "No Extension logs are available."
				$extensionExecutionVerified  = $false
			}
			LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : END ---------------------"
			#endregion

			if ( $ExtensionStatusFromAzure -and $extensionExecutionVerified  -and $ExtensionStatusInStatusFile )
			{
				LogMsg "STATUS FILE VERIFICATION : PASS"
				LogMsg "AZURE STATUS VERIFICATION : PASS"
				LogMsg "EXTENSION EXECUTION VERIFICATION : PASS"
				$ExitCode = "PASS"
			}
			else
			{
				if ( !$ExtensionStatusInStatusFile )
				{
					LogErr "STATUS FILE VERIFICATION : FAIL"
				}
				if ( !$ExtensionStatusFromAzure )
				{
					LogErr "AZURE STATUS VERIFICATION : FAIL"
				}
				if ( !$extensionExecutionVerified )
				{
					LogErr "EXTENSION EXECUTION VERIFICATION : FAIL"
				}
				$ExitCode = "FAIL"
			}
			LogMsg "$metaData result : $ExitCode"
		}
		else
		{
			LogErr "Failed to enable $ExtensionName"
			$ExitCode = "FAIL"
		}
return $ExitCode
}

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
		#Get VMs deployed in the service..
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
		$vmData = $AllVMData

		foreach ( $TaskType in $currentTestData.SubtestValues.split(","))
		{
			try
			{
				LogMsg "$TaskType Test Started.."
				switch ($TaskType)
				{
					"AddUser" 
					{
						$metaData = $TaskType
						[hashtable]$Param=@{};
						$Param['username'] = $NewUser;
						$Param['password'] = $passwd;
						$Param['expiration'] = $expiration;
						$PrivateConfig = ConvertTo-Json $Param;
						$AddUserResult = VerfiyAddUserScenario -vmData $vmData -PrivateConfigString $PrivateConfig -metaData $metaData
						LogMsg "-=-=-=-=-=-=-=-=-=-$metaData : END -=-=-=-=-=-=-=-=-=-"
						$testResult = $AddUserResult
					}

					"ResetPassword" 
					{
						$metaData = $TaskType
						[hashtable]$Param=@{};
						$Param['username'] = $NewUser;
						$Param['password'] = $newpassword;
						$Param['expiration'] = $expiration;
						$PrivateConfig = ConvertTo-Json $Param;
						$ResetPasswordResult = VerfiyResetPasswordScenario -vmData $vmData -PrivateConfigString $PrivateConfig -metaData $metaData -PrevTestStatus $testResult
						LogMsg "-=-=-=-=-=-=-=-=-=-$metaData : END -=-=-=-=-=-=-=-=-=-"
						$testResult = $ResetPasswordResult
					}

					"DeleteUser" 
					{
						if ( ($AddUserResult -eq "PASS") -or ($ResetPasswordResult -eq "PASS") )
						{
							$dependancyCheck = "PASS"
						}
						else
						{
							$dependancyCheck = "ABORTED"
						}
						$metaData = $TaskType
						[hashtable]$Param=@{};
						$Param['remove_user'] = $NewUser;
						$PrivateConfig = ConvertTo-Json $Param;
						$DeleteUserResult = VerfiyDeleteUserScenario -vmData $vmData -PrivateConfigString $PrivateConfig -metaData $metaData -PrevTestStatus $dependancyCheck
						LogMsg "-=-=-=-=-=-=-=-=-=-$metaData : END -=-=-=-=-=-=-=-=-=-"
						$testResult = $DeleteUserResult

					}

					"ResetSSHConfig" 
					{
						$metaData = $TaskType
						[hashtable]$Param=@{};
						$Param['reset_ssh'] = "True";
						$PrivateConfig = ConvertTo-Json $Param;
						$ResetSSHConfigResult = VerfiyResetSSHConfigScenario -vmData $vmData -PrivateConfigString $PrivateConfig -metaData $metaData
						LogMsg "-=-=-=-=-=-=-=-=-=-$metaData : END -=-=-=-=-=-=-=-=-=-"
						$testResult = $ResetSSHConfigResult
					}
				}
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
				$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
			}
		}
	}
	catch
	{}
}
else
{
	$testResult = "FAIL"
	$resultArr += $testResult
	$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
}
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result, $resultSummary
