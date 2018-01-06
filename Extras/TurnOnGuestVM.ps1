param(
    [string]$resourceGroup,
    [string]$roleName,
    [string]$customSecretsFilePath
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

$vmStatus = Get-AzureRMVm -ResourceGroupName $resourceGroup -Name $roleName -Status
if (($vmStatus.Statuses | Where-Object { $_.Code -imatch "PowerState" }).Code -inotmatch "running")
{
    Write-Host "'$roleName' is '$(($vmStatus.Statuses | Where-Object { $_.Code -imatch "PowerState" }).Code)'. Turning it ON..."
    $startStatus = Start-AzureRmVM -Name $roleName -ResourceGroupName $resourceGroup
    if ($startStatus.Status -eq "Succeeded")
    {
        Write-Host "Done."
        exit 0
    }
    else
    {
        Write-Host "There was some issue in turning ON the VM. Please try from web portal."
        exit 1
    }
}
else
{
    Write-Host "'$roleName' is '$(($vmStatus.Statuses | Where-Object { $_.Code -imatch "PowerState" }).Code)'. Exiting."
    exit 0
}