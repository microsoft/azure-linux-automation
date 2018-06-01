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
#        $allVMData = GetAllDeployementData -ResourceGroups $isDeployed
#        Set-Variable -Name allVMData -Value $allVMData -Scope Global
        $testResult = $null
		$clientVMData = $allVMData
		#region CONFIGURE VM FOR N SERIES GPU TEST
		LogMsg "Test VM details :"
		LogMsg "  RoleName : $($clientVMData.RoleName)"
		LogMsg "  Public IP : $($clientVMData.PublicIP)"
		LogMsg "  SSH Port : $($clientVMData.SSHPort)"
		#endregion
		#region Deprovision the VM.
        LogMsg "Deprovisioning $($clientVMData.RoleName)"
		$testJob = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -command "waagent -deprovision --force" -runAsSudo
		LogMsg "Deprovisioning done."
        #endregion
        LogMsg "Shutting down VM.."
        LogMsg "Shutting down VM.."
        $stopVM = Stop-AzureRmVM -Name $clientVMData.RoleName -ResourceGroupName $clientVMData.ResourceGroupName -Force -Verbose
        $stopVM = $true
        if ($stopVM.Status -eq "Succeeded")
        {
            LogMsg "Shutdown successful."
            #Copy the OS VHD with different name.
            if ($ARMImage)
            {
                $newVHDName = "SS-AUTOBUILT-$($ARMImage.Publisher)-$($ARMImage.Offer)-$($ARMImage.Sku)-$($ARMImage.Version)-$Distro"
            }
            if ($OsVHD)
            {
                $newVHDName = "SS-AUTOBUILT-$($OsVHD.Replace('.vhd',''))-$Distro"
            }
            #$newVHDName = $newVHDName.ToUpper()
            $newVHDName = "$newVHDName.vhd"
            Set-Content -Path .\ARM_OSVHD_NAME.azure.env -Value $newVHDName -NoNewline -Force
            $newVHDNameWithTimeStamp = "$newVHDName-$(Get-Date -Format "MM-dd-yyyy")"
            $newVHDNameWithTimeStamp = $newVHDNameWithTimeStamp.ToUpper()
            $newVHDNameWithTimeStamp = "$newVHDNameWithTimeStamp.vhd"
            LogMsg "Sleeping 30 seconds..."
            Sleep -Seconds 30

            #Collect current VHD, Storage Account and Key
            LogMsg "---------------Copy #1: START----------------"
            $saInfoCollected = $false
            $retryCount = 0
            $maxRetryCount = 999
            while(!$saInfoCollected -and ($retryCount -lt $maxRetryCount))
            {
                try
                {
                    $retryCount += 1
                    LogMsg "[Attempt $retryCount/$maxRetryCount] : Getting Storage Account details ..."
                    $GetAzureRMStorageAccount = $null
                    $GetAzureRMStorageAccount = Get-AzureRmStorageAccount
                    if ($GetAzureRMStorageAccount -eq $null)
                    {
                        throw
                    }
                    $saInfoCollected = $true
                }
                catch
                {
                    LogErr "Error in fetching Storage Account info. Retrying in 10 seconds."
                    sleep -Seconds 10
                }
            }
            LogMsg "Collecting OS Disk VHD information."
            $OSDiskVHD = (Get-AzureRmVM -ResourceGroupName $clientVMData.ResourceGroupName -Name $clientVMData.RoleName).StorageProfile.OsDisk.Vhd.Uri
            $currentVHDName = $OSDiskVHD.Trim().Split("/")[($OSDiskVHD.Trim().Split("/").Count -1)]
            $testStorageAccount = $OSDiskVHD.Replace("http://","").Replace("https://","").Trim().Split(".")[0]
            $sourceRegion = $(($GetAzureRmStorageAccount  | Where {$_.StorageAccountName -eq "$testStorageAccount"}).Location)
            $targetStorageAccountType =  [string]($(($GetAzureRmStorageAccount  | Where {$_.StorageAccountName -eq "$testStorageAccount"}).Sku.Tier))
            LogMsg "Check 1: $targetStorageAccountType"
            LogMsg ".\Extras\CopyVHDtoOtherStorageAccount.ps1 -sourceLocation $sourceRegion -destinationLocations $sourceRegion -destinationAccountType $targetStorageAccountType -sourceVHDName $currentVHDName -destinationVHDName $newVHDName"
            .\Extras\CopyVHDtoOtherStorageAccount.ps1 -sourceLocation $sourceRegion -destinationLocations $sourceRegion -destinationAccountType $targetStorageAccountType -sourceVHDName $currentVHDName -destinationVHDName $newVHDName
            LogMsg "---------------Copy #1: END----------------"
            #endregion

            $testResult = "PASS"
        }
        else
        {
            LogErr "Failed to shutdown VM."
            $testResult = "FAIL"
        }
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"
	}
	Finally
	{
		$metaData = "GPU Verification"
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed -SkipVerifyKernelLogs

#Return the result and summery to the test suite script..
return $result, $resultSummary