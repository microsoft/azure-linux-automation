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
		$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $hs1VIP -SSHPort $hs1vm1sshport -username $user -password $password
		$LogFilesPaths = $FoundFiles[0]
		$LogFiles = $FoundFiles[1]
		if ($LogFilesPaths)
		{   
			$retryCount = 1
			$maxRetryCount = 10
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
				if ( Test-Path "$LogDir\extension.log" )
				{
					$extensionOutput = Get-Content -Path $LogDir\extension.log
					if ($extensionOutput -imatch "Start mdsd")
					{
						LogMsg "Extension Agent in started in Linux VM."
						$waitForExtension = $false
						$extensionVerified = $true
					}
					else
					{
						LogMsg "Extension Agent not started in Linux VM"
						$waitForExtension = $true
						$extensionVerified = $false
					}
				}
				else
				{
					$extensionVerified = $false
					LogErr "extension.log file does not present"
					$waitForExtension = $true
					$retryCount += 1
					WaitFor -Seconds 30
				}
			}
			while (($retryCount -lt $maxRetryCount) -and $waitForExtension )
		}
		else
		{
			LogErr "No Extension logs are available."
			$extensionVerified = $false
		}

		$ConfirmExtensionScriptBlock = {
		$vmDetails = Get-AzureVM -ServiceName $isDeployed
 			if ( ( $vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Status -eq "Success" ) -and ($vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Name -imatch "Microsoft.OSTCExtensions.LinuxDiagnostic" ))
			{
				$ExtensionVerfiedWithPowershell = $true
				LogMsg "LinuxDiagnostic extension status is SUCCESS in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
			}
			else
			{
				$ExtensionVerfiedWithPowershell = $false
				LogErr "LinuxDiagnostic extension status is FAILED in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
			}
			return $ExtensionVerfiedWithPowershell
		}
		$ExtensionVerfiedWithPowershell = RetryOperation -operation $ConfirmExtensionScriptBlock -description "Confirming VM DIAGNOSTICS extension from Azure side." -expectResult $true -maxRetryCount 10 -retryInterval 10
		if ( $ExtensionVerfiedWithPowershell -and $extensionVerified)
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result
