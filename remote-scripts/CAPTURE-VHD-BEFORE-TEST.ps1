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

        $stopVM = Stop-AzureRmVM -Name $clientVMData.RoleName -ResourceGroupName $clientVMData.ResourceGroupName -Force -Verbose
        if ($stopVM.Status -eq "Succeeded")
        {
            LogMsg "Shutdown successful."
            #Copy the OS VHD with different name.
            $newVHDName = "SS-AUTOBUILT-$($ARMImage.Publisher)-$($ARMImage.Offer)-$($ARMImage.Sku)-$($ARMImage.Version)-$Distro"
            #$newVHDName = $newVHDName.ToUpper()
            $newVHDName = "$newVHDName.vhd"

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
            $testStorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $(($GetAzureRmStorageAccount  | Where {$_.StorageAccountName -eq "$testStorageAccount"}).ResourceGroupName) -Name $testStorageAccount)[0].Value
            $targetRegions = $currentTestData.regions.Split(",")
            $targetStorageAccounts = ($GetAzureRmStorageAccount | where { ( $_.StorageAccountName -imatch "konkaci" ) -and $targetRegions.Contains($_.PrimaryLocation)}).StorageAccountName
            $destContextArr = @()
            foreach ($targetSA in $targetStorageAccounts)
            {
                #region Copy as Latest VHD
                [string]$SrcStorageAccount = $testStorageAccount
                [string]$SrcStorageBlob = $currentVHDName
                $SrcStorageAccountKey = $testStorageAccountKey
                $SrcStorageContainer = "vhds"

                [string]$DestAccountName =  $targetSA
                [string]$DestBlob = $newVHDName
                $DestAccountKey= (Get-AzureRmStorageAccountKey -ResourceGroupName $(($GetAzureRmStorageAccount  | Where {$_.StorageAccountName -eq "$targetSA"}).ResourceGroupName) -Name $targetSA)[0].Value
                $DestContainer = "vhds"

                $context = New-AzureStorageContext -StorageAccountName $srcStorageAccount -StorageAccountKey $srcStorageAccountKey 
                $expireTime = Get-Date
                $expireTime = $expireTime.AddYears(1)
                $SasUrl = New-AzureStorageBlobSASToken -container $srcStorageContainer -Blob $srcStorageBlob -Permission R -ExpiryTime $expireTime -FullUri -Context $Context 


                #
                # Start Replication to DogFood
                #

                $destContext = New-AzureStorageContext -StorageAccountName $destAccountName -StorageAccountKey $destAccountKey
                $destContextArr += $destContext
                $testContainer = Get-AzureStorageContainer -Name $destContainer -Context $destContext -ErrorAction Ignore
                if ($testContainer -eq $null) {
                    New-AzureStorageContainer -Name $destContainer -context $destContext
                }
                # Start the Copy
                LogMsg "Copying $SrcStorageBlob as $DestBlob from and to storage account $DestAccountName/$DestContainer"
                $out = Start-AzureStorageBlobCopy -AbsoluteUri $SasUrl  -DestContainer $destContainer -DestContext $destContext -DestBlob $destBlob -Force
            }
            #
            # Monitor replication status
            #
            $destContextArr
            $CopyingInProgress = $true
            while($CopyingInProgress)
            {
                $CopyingInProgress = $false
                $newDestContextArr = @()
                foreach ($destContext in $destContextArr)
                {
                    $status = Get-AzureStorageBlobCopyState -Container $destContainer -Blob $destBlob -Context $destContext   
                    if ($status.Status -ne "Success") 
                    {
                        sleep -Milliseconds 100
                        $CopyingInProgress = $true
                        $newDestContextArr += $destContext
                        LogMsg "$DestBlob : $($destContext.StorageAccountName) : Running"
                    }
                    else
                    {
                        $resultSummary +=  CreateResultSummary -testResult "Done" -metaData "$DestBlob : $($destContext.StorageAccountName)" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
                        LogMsg "$DestBlob : $($destContext.StorageAccountName) : Done"
                    }
                }
                if ($CopyingInProgress)
                {
                    LogMsg "$($newDestContextArr.Count) copy operations still in progress."
                    $destContextArr = $newDestContextArr
                    Sleep -Seconds 10
                }
            }
            LogMsg "Copy Done. Bytes Copied:$($status.BytesCopied), Total Bytes:$($status.TotalBytes)"
            
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