<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$ExtensionName = "DockerExtension"
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
					foreach ($fileName in $LogFiles.Split(","))
					{
						if ( $file -imatch $fileName )
						{
							$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $file > $fileName" -runAsSudo
							RemoteCopy -download -downloadFrom $hs1VIP -files $fileName -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
						}
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
							$ExtensionVerifiedInExtensionLog = $true
							break
						}
						else
						{
							$waitForExtension = $true
							$ExtensionVerifiedInExtensionLog = $false
						}
					}
					if ($ExtensionVerifiedInExtensionLog)
					{
						LogMsg "$ExtensionName status is Succeeded from docker-extension.log in Linux VM."
					}
					else
					{
						LogMsg "$ExtensionName status is not Succeeded from docker-extension.log in Linux VM."
						WaitFor -Seconds 60
					}
				}
				else
				{
					$ExtensionVerifiedInExtensionLog = $false
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
			$ExtensionVerifiedInExtensionLog = $false
		}
		if ( $UseAzureResourceManager )
		{
			$ConfirmExtensionScriptBlock = {
				$ExtensionStatus = Get-AzureResource -OutputObjectFormat New -ResourceGroupName $isDeployed  -ResourceType "Microsoft.Compute/virtualMachines/extensions" -ExpandProperties
				if ( ($ExtensionStatus.Properties.ProvisioningState -eq "Succeeded") -and ( $ExtensionStatus.Properties.Type -eq $ExtensionName ) )
				{
					LogMsg "$ExtensionName status is Succeeded in Properties.ProvisioningState"
					$ExtensionVerfiedWithPowershell = $true
				}
				else
				{
					LogErr "$ExtensionName status is Failed in Properties.ProvisioningState"
					$ExtensionVerfiedWithPowershell = $false
				}
				return $ExtensionVerfiedWithPowershell
			}
		}
		else
		{
			$ConfirmExtensionScriptBlock = {
		
			$vmDetails = Get-AzureVM -ServiceName $isDeployed
				if ( ( $vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Status -eq "Success" ) -and ($vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Operation -imatch "Docker" ))
				{
					$ExtensionVerfiedWithPowershell = $true
					LogMsg "$ExtensionName status is SUCCESS in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
				}
				else
				{
					$ExtensionVerfiedWithPowershell = $false
					LogErr "$ExtensionName status is FAILED in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
				}
				return $ExtensionVerfiedWithPowershell
			}
		}
		$ExtensionVerfiedWithPowershell = RetryOperation -operation $ConfirmExtensionScriptBlock -description "Confirming $ExtensionName from Azure side." -expectResult $true -maxRetryCount 50 -retryInterval 60
		
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
		if ($DockerStatusInWaagent -imatch "docker-extension install PID" -and $DockerStatusInWaagent -imatch "installCommand completed")
		{
			LogMsg "Docker status is enabled in waagent.log."
			$ExtensionVerifiedInWaagentLog = $true
		}
		else
		{
			LogErr "Docker status is not enabled in waagent.log."
			$ExtensionVerifiedInWaagentLog = $false
		}
		if ( $ExtensionVerfiedWithPowershell -and $ExtensionVerifiedInExtensionLog -and $ExtensionVerifiedInWaagentLog -and $ExtensionVerifiedInVM)
		{
			$testResult = "PASS"
		}
		else
		{
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
#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
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
