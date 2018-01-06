param(
    [string]$resourceGroup,
    [string]$roleName,
    [int]$idleTimeMinutes=15,
    [int]$idleCPUUsagePercent=1,
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
if (($vmStatus.Statuses | Where-Object { $_.Code -imatch "PowerState" }).Code -imatch "running")
{
    $startTime = 60 - $idleTimeMinutes

    $subscriptionID = $xmlSecrets.secrets.SubscriptionID

    $resourceID = "/subscriptions/$subscriptionID/resourceGroups/$resourceGroup/providers/Microsoft.Compute/virtualMachines/$roleName"
    $tempObj = ((Get-AzureRmMetric -ResourceId $resourceID -ErrorAction SilentlyContinue ).Data)[$startTime .. 60]
    $maxUsage = ( $tempObj.Average | Measure-Object -Maximum -ErrorAction SilentlyContinue).Maximum
    $avgUsage = ( $tempObj.Average | Measure-Object -Average -ErrorAction SilentlyContinue).Average
    $minUsage = ( $tempObj.Average | Measure-Object -Minimum -ErrorAction SilentlyContinue).Minimum
    $nullValueCount = ($tempObj | Where-Object { $_.Average -eq $null }).count
    Write-Host
    $tempObj | Format-Table TimeStamp,Average
    Write-Host
    Write-Host "MIN: $($minUsage)%, MAX : $($maxUsage)%, AVG : $($avgUsage)%"

    if ( $nullValueCount -gt 1)
    {
        Write-Host "We found some NULL CPU usage. '$roleName' may be started recently. Hence, not turning off. Exiting."
        exit 0
    }
    if ($maxUsage -le $idleCPUUsagePercent)
    {
        Write-Host "Guest is idle for $idleTimeMinutes minutes. Turning it off..."
        $stopStatus = Stop-AzureRmVM -Name $roleName -ResourceGroupName $resourceGroup -Force
        if ($stopStatus.Status -eq "Succeeded")
        {
            Write-Host "Done."
        }
        else
        {
            Write-Host "There was some issue in turning off the VM. Please try from web portal."
            exit 1
        }
    }
    else
    {
        Write-Host "Observed CPU activity in last $idleTimeMinutes minutes. Guest is not idle."
        exit 0
    }
}
else
{
    Write-Host "'$roleName' is '$(($vmStatus.Statuses | Where-Object { $_.Code -imatch "PowerState" }).Code)'. Exiting."
    exit 0
}