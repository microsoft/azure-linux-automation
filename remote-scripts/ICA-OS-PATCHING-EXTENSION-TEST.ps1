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
		$ExtensionName = "OSPatchingForLinux"
		$FoundFiles = GetFilePathsFromLinuxFolder -folderToSearch $folderToSearch -IpAddress $hs1VIP -SSHPort $hs1vm1sshport -username $user -password $password
		$LogFilesPaths = $FoundFiles[0]
		$LogFiles = $FoundFiles[1]
		$retryCount = 1
		$maxRetryCount = 20
		if ($LogFilesPaths)
		{   
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
				if ( Test-Path "$LogDir\extension.log" )
				{
					$extensionOutput = Get-Content -Path $LogDir\extension.log
					$waitForExtension = $false
					#Check for the patch list
					foreach ($line in $extensionOutput.Split("`n"))
					{
						if ($patchListNotAvailable)
						{ 
							if ( $line -imatch "Patch list:" )
							{
								$patchList = $line.Trim()
								$patchListNotAvailable = $false
							}
						}
						else
						{
							$patchListNotAvailable = $true

						}
						if ($line -imatch "Start to install \d patches")
						{
							$totalPackages = $line.Trim().replace("[","").replace("]","").Split()[5]
						}
					}
					if ( $patchListNotAvailable )
					{
						LogMsg "No packages scheduled to update."
						$extensionVerified = $true
						
					}
					else
					{
						LogMsg "Total Update Packages : $totalPackages"
						LogMsg "Packages to be udpated by extension : "
						$patchList = $patchList.Split()
						$patchListCount = $patchList.Count
						for ( $i = 0; $i -le ($totalPackages) ; $i++ )
						{
						   LogMsg $patchList[($patchListCount-$i)]
						}
						$extensionVerified = $true
					}
					$waitForExtension = $false
				}
				else
				{
					$extensionVerified = $false
					LogErr "extension.log file does not present"
					$waitForExtension = $true
					WaitFor -Seconds 30
				}
				$retryCount += 1
			}
			while (($retryCount -lt $maxRetryCount) -and $waitForExtension )
		}
		else
		{
			LogErr "No Extension logs are available."
			$extensionVerified = $false
		}
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
