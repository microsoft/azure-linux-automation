param(
    $Age=30,
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

$GetAzureRmStorageAccount = Get-AzureRmStorageAccount
$targetSA = $GetAzureRmStorageAccount | Where-Object { $_.StorageAccountName -imatch "konkaci" }
$TotalContainers = 0
$TotalCleanableContainers = 0
$TotalRecentContainers = 0
foreach ($storage in $targetSA)
{
    $currentStorageContext = New-AzureStorageContext -StorageAccountName $storage.StorageAccountName -StorageAccountKey $((Get-AzureRmStorageAccountKey -ResourceGroupName $storage.ResourceGroupName -Name $storage.StorageAccountName)[0].Value.ToString())
    $currentContainers = Get-AzureStorageContainer -Context $currentStorageContext | Where-Object { $_.Name -imatch "bootdiagnostics" }
    foreach ($container in $currentContainers)
    {
        $TotalContainers += 1
        $containerAge = 0
        $containerAge = ((Get-Date) - ($container.LastModified).Date).Days
        Write-Host "$TotalCleanableContainers. $($storage.StorageAccountName) : $($container.Name) : $containerAge days old : " -NoNewline
        if ($containerAge -gt $Age)
        {
            try
            {
                $out = Remove-AzureStorageContainer -Name "$($container.Name)" -Context $currentStorageContext -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Host "Deleted."
                $TotalCleanableContainers += 1
            }
            catch
            {
                Write-Host "ERROR in delete."
            }
        }
        else
        {
            $TotalRecentContainers += 1
            Write-Host "Skipped."
        }
    }
}
Write-Host "Total Containers : $TotalContainers"
Write-Host "Total Cleaned Containers: : $TotalCleanableContainers"
Write-Host "Total Recent Containers (not more than $Age days old): $TotalRecentContainers"

