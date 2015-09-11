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
		RemoteCopy -download -downloadFrom $hs1VIP -files "/var/log/waagent.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		$lsOutput = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls /var/log/" -runAsSudo
		LogMsg -msg $lsOutput -LinuxConsoleOuput
		if ($lsOutput -imatch "CustomExtensionSuccessful")
		{
			$extensionVerified = $true
		}
		else
		{
			$extensionVerified = $false
		}
		$ExtensionName = "CustomScriptForLinux"
		if ( $UseAzureResourceManager )
		{
			$ConfirmExtensionScriptBlock = {
				$ExtensionStatus = Get-AzureResource -OutputObjectFormat New -ResourceGroupName $isDeployed  -ResourceType "Microsoft.Compute/virtualMachines/extensions" -ExpandProperties
				if ( ($ExtensionStatus.Properties.ProvisioningState -eq "Succeeded") -and ( $ExtensionStatus.Properties.Type -eq $ExtensionName ) )
				{
					LogMsg "$ExtensionName extension status is Succeeded in Properties.ProvisioningState"
					$ExtensionVerfiedWithPowershell = $true
				}
				else
				{
					LogErr "$ExtensionName extension status is Failed in Properties.ProvisioningState"
					$ExtensionVerfiedWithPowershell = $false
				}
				return $ExtensionVerfiedWithPowershell
			}
		}
		else
		{
			$ConfirmExtensionScriptBlock = {
		
			$vmDetails = Get-AzureVM -ServiceName $isDeployed
 				if ( ( $vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Status -eq "Success" ) -and ($vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Name -imatch $ExtensionName ))
				{
					$ExtensionVerfiedWithPowershell = $true
					LogMsg "$ExtensionName extension status is SUCCESS in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
				}
				else
				{
					$ExtensionVerfiedWithPowershell = $false
					LogErr "$ExtensionName extension status is FAILED in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
				}
				return $ExtensionVerfiedWithPowershell
			}
		}

		$ExtensionVerfiedWithPowershell = RetryOperation -operation $ConfirmExtensionScriptBlock -description "Confirming $ExtensionName extension from Azure side." -expectResult $true -maxRetryCount 10 -retryInterval 10
		
		if ( $ExtensionVerfiedWithPowershell -and $extensionVerified )
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
