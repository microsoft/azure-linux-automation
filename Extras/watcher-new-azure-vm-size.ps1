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

$newFile = "Z:\Jenkins_Shared_Do_Not_Delete\userContent\shared\azure-vm-sizes.txt"
$oldFile = "Z:\Jenkins_Shared_Do_Not_Delete\userContent\shared\azure-vm-sizes-base.txt"
$fallback ="Z:\Jenkins_Shared_Do_Not_Delete\userContent\shared\azure-vm-sizes-fallback.txt"
Write-Host "Getting regions"
Copy-Item -Path $oldFile -Destination $fallback -Verbose -Force
Remove-Item -Path $oldFile -Verbose -Force
Copy-Item -Path $newFile -Destination $oldFile -Verbose -Force
Remove-Item -Path $newFile -Force -Verbose
$allRegions = (Get-AzureRMLocation | Where {$_.Providers.Contains("Microsoft.Compute")}).Location
foreach ( $region in $allRegions)
{
    try
    {
        Write-Host "Getting VM sizes from $region"
        $vmSizes = Get-AzureRmVMSize -Location $region
        foreach ( $vmSize in $vmSizes )
        {
            Add-Content -Value "$region $($vmSize.Name)" -Path $newFile -Force
        }
    }
    catch
    {
        Write-Error "Failed to fetch data from $region."
    }
}

$newVMSizes = Compare-Object -ReferenceObject (Get-Content -Path $oldFile ) -DifferenceObject (Get-Content -Path $newFile)
$newVMs = 0
$newVMsString = $null
foreach ( $newSize in $newVMSizes )
{
    if ( $newSize.SideIndicator -eq '=>')
    {
        $newVMs += 1
        Write-Host "$newVMs. $($newSize.InputObject)"
        $newVMsString += "$($newSize.InputObject),"
    }
    else
    {
        Write-Host "$newVMs. $($newSize.InputObject) $($newSize.SideIndicator)"
    }
}
if ( $newVMs -eq 0)
{
    Write-Host "No New sizes today."
    Set-Content -Value "NO_NEW_VMS" -Path todaysNewVMs.txt -NoNewline
}
else
{
    Set-Content -Value $($newVMsString.TrimEnd(",")) -Path todaysNewVMs.txt -NoNewline
}
Write-Host "Exiting with zero"
exit 0