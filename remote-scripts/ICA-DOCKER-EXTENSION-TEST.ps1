<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
		$hs1vm1Hostname = $AllVMData.RoleName
		$ExtensionVerfiedWithPowershell = $false
		$LogFilesPaths = ""
		$LogFiles = ""
		$folderToSearch = "/var/log/azure"
		$ExtensionName = "DockerExtension"
		$statusFile = GetStatusFileNameToVerfiy -vmData $AllVMData -expectedExtensionName $ExtensionName
		
		#region check Extension Status from 0.status file
		LogMsg "--------------------- STAGE 1/3 : verification of $statusFile : START ---------------------"

		if ( $statusFile )
		{
			$statusFilePath = GetFilePathsFromLinuxFolder -folderToSearch "/var/lib/waagent" -IpAddress $allVMData.PublicIP -SSHPort $allVMData.SSHPort -username $user -password $password -expectedFiles "$statusFile"
			$ExtensionStatusInStatusFile = GetExtensionStatusFromStatusFile -statusFilePaths $statusFilePath[0] -ExtensionName $ExtensionName -vmData $allVMData
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
		$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $hs1VIP -SSHPort $hs1vm1sshport -username $user -password $password
		$LogFilesPaths = $FoundFiles[0]
		$LogFiles = $FoundFiles[1]
		if ($LogFilesPaths)
		{   
			$retryCount = 1
			$maxRetryCount = 50
			do
			{   LogMsg "Attempt : $retryCount/$maxRetryCount : Checking extension log files...."
				foreach ($file in $LogFilesPaths.Split(","))
				{
					$fileName = $file.Split("/")[$file.Split("/").Count -1]
					if ( $file -imatch $ExtensionName )
					{
						$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $file > $fileName" -runAsSudo
						RemoteCopy -download -downloadFrom $hs1VIP -files $fileName -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
					}
					else
					{
						LogErr "Unexpected Extension Found : $($file.Split("/")[4]) with version $($file.Split("/")[5])"
						LogMsg "Skipping download for : $($file.Split("/")[4]) : $fileName"
					}
				}
				if ( Test-Path "$LogDir\docker-extension.log" )
				{
					$extensionOutput = Get-Content -Path $LogDir\docker-extension.log
					foreach ($line in $extensionOutput.Split("`n"))
					{
						if (($line -imatch "completed: 'enable'") -and ($line -imatch "DockerExtension"))
						{
							$waitForExtension = $false
							$extensionExecutionVerified = $true
							break
						}
						else
						{
							$waitForExtension = $true
							$extensionExecutionVerified = $false
						}
					}
					if ($extensionExecutionVerified)
					{
						LogMsg "$ExtensionName status is Succeeded from docker-extension.log in Linux VM."
					}
					else
					{
						LogErr "$ExtensionName status is not Succeeded from docker-extension.log in Linux VM."
						WaitFor -Seconds 60
					}
				}
				else
				{
					$extensionExecutionVerified = $false
					LogErr "docker-extension.log file does not present"
					$waitForExtension = $true
					WaitFor -Seconds 60
				}
				$retryCount += 1
			}
			while (($retryCount -lt $maxRetryCount) -and $waitForExtension )
		}
		else
		{
			LogErr "No Extension logs are available."
			$extensionExecutionVerified = $false
		}
		
		$DockerInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "docker info" -runAsSudo -ignoreLinuxExitCode
		if ($DockerInfo -imatch "Operating System")
		{
			LogMsg "Docker installed succesfully in Linux VM."
			$ExtensionVerifiedInVM = $true
		}
		else
		{
			LogErr "Docker not installed in Linux VM"
			$ExtensionVerifiedInVM = $false
		}

		$DockerStatusInWaagent = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /var/log/waagent.log" -runAsSudo -ignoreLinuxExitCode
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /var/log/waagent.log > waagent.log" -runAsSudo
		RemoteCopy -download -downloadFrom $hs1VIP -files waagent.log -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password

		if ( ($DockerStatusInWaagent -imatch "Microsoft.Azure.Extensions.DockerExtension") -and ( ( $DockerStatusInWaagent -imatch "succeeded: scripts/run-in-background.sh enable") -or ( $DockerStatusInWaagent -imatch "Spawned scripts/run-in-background.sh enable PID") ) ) 
		{
			LogMsg "Docker status is enabled in waagent.log."
			$ExtensionVerifiedInWaagentLog = $true
		}
		else
		{
			LogErr "Docker status is not enabled in waagent.log."
			$ExtensionVerifiedInWaagentLog = $false
		}

		LogMsg "--------------------- STAGE 3/3 : verification of Extension Execution : END ---------------------"
		#endregion

		if ($ExtensionStatusFromAzure -and $extensionExecutionVerified  -and $ExtensionStatusInStatusFile -and $ExtensionVerifiedInWaagentLog -and $ExtensionVerifiedInVM)
		{
			LogMsg "STATUS FILE VERIFICATION : PASS"
			LogMsg "AZURE STATUS VERIFICATION : PASS"
			LogMsg "EXTENSION EXECUTION VERIFICATION : PASS"
			$testResult = "PASS"
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
			$testResult = "FAIL"
		}
		LogMsg "Test result : $testResult"
	}

	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = ""
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
return $result
