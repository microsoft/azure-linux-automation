

param(
    $sourceLocation,
    $destinationLocations,
    $destinationAccountType,
    $sourceVHDName,
    $destinationVHDName,
    $customSecretsFilePath
)

if ( $customSecretsFilePath ) {
    $secretsFile = $customSecretsFilePath
    Write-Host "Using user provided secrets file: $($secretsFile | Split-Path -Leaf)"
}
if ($env:Azure_Secrets_File) {
    $secretsFile = $env:Azure_Secrets_File
    Write-Host "Using predefined secrets file: $($secretsFile | Split-Path -Leaf) in Jenkins Global Environments."
}
if ( $secretsFile -eq $null ) {
    Write-Host "ERROR: Azure Secrets file not found in Jenkins / user not provided -customSecretsFilePath" -ForegroundColor Red -BackgroundColor Black
    exit 1
}


if ( Test-Path $secretsFile) {
    Write-Host "AzureSecrets.xml found."
    .\AddAzureRmAccountFromSecretsFile.ps1 -customSecretsFilePath $secretsFile
    $xmlSecrets = [xml](Get-Content $secretsFile)
    Set-Variable -Name xmlSecrets -Value $xmlSecrets -Scope Global
}
else {
    Write-Host "AzureSecrets.xml file is not added in Jenkins Global Environments OR it is not bound to 'Azure_Secrets_File' variable." -ForegroundColor Red -BackgroundColor Black
    Write-Host "Aborting." -ForegroundColor Red -BackgroundColor Black
    exit 1
}
if ($destinationVHDName)
{
    $newVHDName = $destinationVHDName
}
else
{
    $newVHDName = $sourceVHDName
}
if (!$destinationAccountType)
{
    $destinationAccountType="Standard,Premium"
}
$regionName = $sourceLocation.Replace(" ","").Replace('"',"").ToLower()
$regionStorageMapping = [xml](Get-Content .\XML\RegionAndStorageAccounts.xml)
$sourceStorageAccountName = $regionStorageMapping.AllRegions.$regionName.StandardStorage

#Collect current VHD, Storage Account and Key
$saInfoCollected = $false
$retryCount = 0
$maxRetryCount = 999
while(!$saInfoCollected -and ($retryCount -lt $maxRetryCount))
{
    try
    {
        $retryCount += 1
        Write-Host "[Attempt $retryCount/$maxRetryCount] : Getting Storage Account details ..."
        $GetAzureRMStorageAccount = $null
        $GetAzureRMStorageAccount = Get-AzureRmStorageAccount
        if ($GetAzureRMStorageAccount -eq $null)
        {
            $saInfoCollected = $false
        }
        else
        {
            $saInfoCollected = $true
        }
    }
    catch
    {
        LogErr "Error in fetching Storage Account info. Retrying in 10 seconds."
        sleep -Seconds 10
        $saInfoCollected = $false
    }
}
$currentVHDName = $sourceVHDName
$testStorageAccount = $sourceStorageAccountName
$testStorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $(($GetAzureRmStorageAccount  | Where {$_.StorageAccountName -eq "$testStorageAccount"}).ResourceGroupName) -Name $testStorageAccount)[0].Value

$targetRegions = (Get-AzureRmLocation).Location
if ($destinationLocations)
{
    $targetRegions = $destinationLocations.Split(",")
}
else
{
    $targetRegions = (Get-AzureRmLocation).Location
}
$targetStorageAccounts = @()
foreach ($newRegion in $targetRegions)
{
    if ( $destinationAccountType -imatch "Standard")
    {
        $targetStorageAccounts +=  $regionStorageMapping.AllRegions.$newRegion.StandardStorage
    }
    if ( $destinationAccountType -imatch "Premium")
    {
        $targetStorageAccounts +=  $regionStorageMapping.AllRegions.$newRegion.PremiumStorage
    }   
}
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
    $testContainer = Get-AzureStorageContainer -Name $destContainer -Context $destContext -ErrorAction Ignore
    if ($testContainer -eq $null) {
        New-AzureStorageContainer -Name $destContainer -context $destContext
    }
    # Start the Copy
    if (($SrcStorageAccount -eq $DestAccountName) -and ($SrcStorageBlob -eq $DestBlob))
    {
        Write-Host "Skipping copy for : $DestAccountName as source storage account and VHD name is same."
    }
    else
    {
        Write-Host "Copying $SrcStorageBlob as $DestBlob from and to storage account $DestAccountName/$DestContainer"
        $out = Start-AzureStorageBlobCopy -AbsoluteUri $SasUrl  -DestContainer $destContainer -DestContext $destContext -DestBlob $destBlob -Force
        $destContextArr += $destContext
    }
}
#
# Monitor replication status
#
$CopyingInProgress = $true
while($CopyingInProgress)
{
    $CopyingInProgress = $false
    $newDestContextArr = @()
    foreach ($destContext in $destContextArr)
    {
        $status = Get-AzureStorageBlobCopyState -Container $destContainer -Blob $destBlob -Context $destContext
        if ($status.Status -eq "Success")
        {
            Write-Host "$DestBlob : $($destContext.StorageAccountName) : Done : 100 %"
        }
        elseif ($status.Status -eq "Failed")
        {
            Write-Host "$DestBlob : $($destContext.StorageAccountName) : Failed."
        }
        elseif ($status.Status -eq "Pending")
        {
            sleep -Milliseconds 100
            $CopyingInProgress = $true
            $newDestContextArr += $destContext
            $copyPercent = [math]::Round((($status.BytesCopied/$status.TotalBytes) * 100),2)
            Write-Host "$DestBlob : $($destContext.StorageAccountName) : Running : $copyPercent %"
        }
    }
    if ($CopyingInProgress)
    {
        Write-Host "--------$($newDestContextArr.Count) copy operations still in progress.-------"
        $destContextArr = $newDestContextArr
        Sleep -Seconds 10
    }
}
Write-Host "All Copy Operations completed successfully."
#endregion