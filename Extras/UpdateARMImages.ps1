Param( $PublisherName, $OutputFilePath )
#Prepare workspace for automation.

$currentDir = $PWD
& "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\ShortcutStartup.ps1"
Disable-AzureDataCollection
cd $currentDir

$exitValue = 0
if ( $customSecretsFilePath ) {
    $secretsFile = $customSecretsFilePath
    Write-Host "Using user provided secrets filQ: $($secretsFile | Split-Path -Leaf)"
}
if ($env:Azure_Secrets_File) {
    $secretsFile = $env:Azure_Secrets_File
    Write-Host "Using predefined secrets filQ: $($secretsFile | Split-Path -Leaf) in Jenkins Global Environments."
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



$tab = "	"

#region Collect Images.
try
{

    $tab = "	"
    if ($OutputFilePath)
    {
        $FilePath = $OutputFilePath
    }
    else 
    {
        Write-Host "Default ouput file : .\ARMImages.txt"
        $FilePath = ".\ARMImages.txt"        
    }
    $Location = "westus2"
    if ($PublisherName)
    {
        $allRMPubs = $PublisherName
    }
    else 
    {
        $allRMPubs = "Canonical,SUSE,Oracle,CoreOS,RedHat,OpenLogic,credativ,kali-linux,MicrosoftRServer,MicrosoftSharePoint,MicrosoftSQLServer,MicrosoftVisualStudio,MicrosoftWindowsServer,MicrosoftWindowsServerEssentials,MicrosoftWindowsServerHPCPack"
    }
    
    $finalRMImages = @()
    $ARMImageFileContents = "Publisher	Offer	SKU	Version`n"
    foreach ( $newPub in $allRMPubs.Split(",") )
    {
        $offers = Get-AzureRmVMImageOffer -PublisherName $newPub -Location $Location
        if ($offers) 
        {
            Write-Host "Found $($offers.Count) offers for $($newPub)..."
            foreach ( $offer in $offers )
            {
                $SKUs = Get-AzureRmVMImageSku -Location $Location -PublisherName $newPub -Offer $offer.Offer -ErrorAction SilentlyContinue
                Write-Host "|--Found $($SKUs.Count) SKUs for $($offer.Offer)..."
                foreach ( $SKU in $SKUs )
                {
                    $rmImages = Get-AzureRmVMImage -Location $Location -PublisherName $newPub -Offer $offer.Offer -Skus $SKU.Skus
                    Write-Host "|--|--Found $($rmImages.Count) Images for $($SKU.Skus)..."
                    if ( $rmImages.Count -gt 1 )
                    {
                        $isLatestAdded = $false
                    }
                    else
                    {
                        $isLatestAdded = $true
                    }
                    foreach ( $rmImage in $rmImages )
                    {
                        if ( $isLatestAdded )
                        {
                            Write-Host "|--|--|--Added Version $($rmImage.Version)..."
                            $finalRMImages += $rmImage
                            $ARMImageFileContents += $newPub + $tab + $offer.Offer + $tab + $SKU.Skus + $tab + $newPub + " " + $offer.Offer + " " + $SKU.Skus + " " + $rmImage.Version + "`n"
                        }
                        else
                        {
                            Write-Host "|--|--|--Added Generalized version: latest..."
                            $finalRMImages += $rmImage
                            $ARMImageFileContents += $newPub + $tab + $offer.Offer + $tab + $SKU.Skus + $tab + $newPub + " " + $offer.Offer + " " + $SKU.Skus + " " + "latest" + "`n"
                            Write-Host "|--|--|--Added Version $($rmImage.Version)..."
                            $finalRMImages += $rmImage
                            $ARMImageFileContents += $newPub + $tab + $offer.Offer + $tab + $SKU.Skus + $tab + $newPub + " " + $offer.Offer + " " + $SKU.Skus + " " + $rmImage.Version + "`n"
                            $isLatestAdded = $true
                        }
                    }
                }
            }
        }
    }
    $ARMImageFileContents = $ARMImageFileContents.TrimEnd("`n")
    Set-Content -Value $ARMImageFileContents -Path $FilePath -Force -Verbose
}
catch 
{
    Write-Host "Error in gathering ARM images."
}

#endregion