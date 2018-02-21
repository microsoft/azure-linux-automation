param
(
    $filePaths,
    $destinationStorageAccount,
    $destinationContainer,
    $destinationFolder,
    $destinationStorageKey,
    [string]$customSecretsFilePath=$null

)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
if ( $customSecretsFilePath )
{
	$secretsFile = $customSecretsFilePath
	Write-Host "Using provided secrets file: $($secretsFile | Split-Path -Leaf)"
}
if  ($env:Azure_Secrets_File)
{
	$secretsFile = $env:Azure_Secrets_File
	Write-Host "Using predefined secrets file: $($secretsFile | Split-Path -Leaf) in Jenkins Global Environments."
}
if ( $secretsFile -eq $null )
{
    Write-Host "ERROR: Azure Secrets file not found in Jenkins / user not provided -customSecretsFilePath" -ForegroundColor Red -BackgroundColor Black
    exit 1
}


if ( Test-Path $secretsFile)
{
	Write-Host "$($secretsFile | Split-Path -Leaf) found."
    $xmlSecrets = [xml](Get-Content $secretsFile)
    .\AddAzureRmAccountFromSecretsFile.ps1 -customSecretsFilePath $secretsFile
	$subscriptionID = $xmlSecrets.secrets.SubscriptionID
}
else
{
	Write-Host "$($secretsFile | Split-Path -Leaf) file is not added in Jenkins Global Environments OR it is not bound to 'Azure_Secrets_File' variable." -ForegroundColor Red -BackgroundColor Black
	Write-Host "Aborting." -ForegroundColor Red -BackgroundColor Black
	exit 1
}

if ( Test-Path $secretsFile )
{
	Write-Host "$($secretsFile | Split-Path -Leaf) found."
	Write-Host "---------------------------------"
	$xmlSecrets = [xml](Get-Content $secretsFile)
}
else
{
	Write-Host "$($secretsFile | Spilt-Path -Leaf) file is not added in Jenkins Global Environments OR it is not bound to 'Azure_Secrets_File' variable."
	Write-Host "If you are using local secret file, then make sure file path is correct."
	Write-Host "Aborting."
	exit 1
}

#---------------------------------------------------------[Script Start]--------------------------------------------------------
#$allVMData = GetAllDeployementData -ResourceGroups "ICA-RG-SingleVM-SIVAU16-12-18-12-13-4891"
$utctime = (Get-Date).ToUniversalTime()
$DateTimeUTC = "$($utctime.Year)-$($utctime.Month)-$($utctime.Day) $($utctime.Hour):$($utctime.Minute):$($utctime.Second)"

try
{
    if ($destinationStorageKey)
    {
        Write-Host "Using user provided storage account key." 
    }
    else 
    {
        Write-Host "Getting $destinationStorageAccount storage account key..."
        $allResources = Get-AzureRmResource
        $destSARG = ($allResources | Where { $_.ResourceType -imatch "storageAccounts" -and $_.ResourceName -eq "$destinationStorageAccount" }).ResourceGroupName
        $keyObj = Get-AzureRmStorageAccountKey -ResourceGroupName $destSARG -Name $destinationStorageAccount
        $destinationStorageKey = $keyObj[0].Value
    }
    $containerName = "$destinationContainer"
    $storageAccountName = $destinationStorageAccount
    $blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $destinationStorageKey
    $uploadedFiles = @()
    foreach($fileName in $filePaths.Split(","))
    {
        $ticks = (Get-Date).Ticks
        #$fileName = "$LogDir\$($vmData.RoleName)-waagent.log.txt"
        $blobName = "$destinationFolder/$($fileName | Split-Path -Leaf)"
        Write-Host 
        $out = Set-AzureStorageBlobContent -File $filename -Container $containerName -Blob $blobName -Context $blobContext -Force -ErrorAction Stop
        Write-Host "$($blobContext.BlobEndPoint)$containerName/$blobName : Success"
        $uploadedFiles += "$($blobContext.BlobEndPoint)$containerName/$blobName"
    }
    return $uploadedFiles
}
catch
{
    $line = $_.InvocationInfo.ScriptLineNumber
    $script_name = ($_.InvocationInfo.ScriptName).Replace($PWD,".")
    $ErrorMessage =  $_.Exception.Message
    Write-Host "EXCEPTION : $ErrorMessage"
    Write-Host "Source : Line $line in script $script_name."
    Write-Host "ERROR : $($blobContext.BlobEndPoint)/$containerName/$blobName : Failed"
}
