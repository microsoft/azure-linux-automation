Param( $BuildNumber=$env:BUILD_NUMBER,

[Parameter(Mandatory=$true)]
[string] $testLocation,

[Parameter(Mandatory=$true)]
[string] $DistroIdentifier, 

[Parameter(Mandatory=$true)]
[string] $testCycle,

[string] $ARMImageName,
[string] $OsVHD,

[Parameter(Mandatory=$true)]  
[string] $OverrideVMSize,

[switch] $EnableAcceleratedNetworking,
[string] $customKernel, 
[string] $customLIS, 
[string] $customLISBranch,
[switch] $ForceDeleteResources,
[string] $customSecretsFilePath = "",
[string] $ArchiveLogDirectory = "",
[string] $ResultDBTable = "",
[string] $ResultDBTestTag = "",
[string] $RunSelectedTests="",
[string] $StorageAccount=""
)

#---------------------------------------------------------[Initializations]--------------------------------------------------------
Write-Host "-----------$PWD---------"
if ( $pwd.Path.Length -gt 64)
{
    $randomNumber = Get-Random -Maximum 999999999999 -Minimum 111111111111
    $originalWorkingDirectory = $pwd
    Write-Host "Current working directory lenght is greather than 64. Need to change the working directory."
    $currentDrive = $pwd | Split-Path -Qualifier
    New-Item -ItemType Directory -Path "$currentDrive\AzureTests" -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path "$currentDrive\AzureTests\$randomNumber" -Force -ErrorAction SilentlyContinue | Out-Null 
    $finalWorkingDirectory = "$currentDrive\AzureTests\$randomNumber"
    Copy-Item -Path "*" -Destination $finalWorkingDirectory -Recurse | Out-Null
    Set-Location -Path $finalWorkingDirectory | Out-Null
    Write-Host "Wroking directory changed to $finalWorkingDirectory"
}

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

if ( $ARMImageName -eq $null -and $OsVHD -eq $null)
{
    Write-Host "MISSING PARAMETER: ARMImage and OsVHD parameters are missing. Please give atleast one."
}

#region Set Jenkins specific variables.
if ($env:BUILD_NUMBER -gt 0)
{
    Write-Host "Detected Jenkins environment."
    $xmlConfigFileFinal = "$PWD\Azure_ICA_all_run-$env:JOB_NAME-$env:BUILD_NUMBER.xml"
    $xmlConfigFileFinal = $xmlConfigFileFinal.Replace('/','-')
}
else
{
    Write-Host "Detected local environment."
    $xmlConfigFileFinal = "$PWD\Azure_ICA_all_run-$testCycle-$DistroIdentifier.xml"
}

#region Select Storage Account Type
$regionName = $testLocation.Replace(" ","").Replace('"',"").ToLower()
$regionStorageMapping = [xml](Get-Content .\XML\RegionAndStorageAccounts.xml)
if ( $StorageAccount -imatch "ExistingStorage_Standard" )
{
    $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.StandardStorage
}
elseif ( $StorageAccount -imatch "ExistingStorage_Premium" )
{
    $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.PremiumStorage
}
elseif ( $StorageAccount -imatch "NewStorage_Standard" )
{
    $StorageAccountName = "NewStorage_Standard_LRS"
}
elseif ( $StorageAccount -imatch "NewStorage_Premium" )
{
    $StorageAccountName = "NewStorage_Premium_LRS"
}
elseif ($StorageAccount -eq "")
{
    $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.StandardStorage
    Write-Host "Auto selecting storage account : $StorageAccountName as per your test region."
     
}
#if ($defaultDestinationStorageAccount -ne $StorageAccountName)
#{
#   $OsVHD = "https://$defaultDestinationStorageAccount.blob.core.windows.net/vhds/$OsVHD"
#}
#endregion

#Write-Host "Getting '$StorageAccountName' storage account details..."
#$testLocation = (Get-AzureRmLocation | Where { $_.Location -eq $((Get-AzureRmResource | Where { $_.Name -eq "$StorageAccountName"}).Location)}).DisplayName

#region Prepare workspace for automation.
Set-Content -Value "<pre>" -Path .\FinalReport.txt -Force
Add-Content -Value "Build process aborted manually. Please check attached logs for more details..." -Path .\FinalReport.txt -Force
Add-Content -Value "</pre>" -Path .\FinalReport.txt -Force
mkdir .\report -Force -ErrorAction SilentlyContinue | Out-Null
Set-Content -Value "" -Path .\report\testSummary.html -Force 
Set-Content -Value "" -Path .\report\lastLogDirectory.txt -Force 

#Copy-Item J:\Jenkins\userContent\azure-linux-automation\* -Destination . -Recurse -Force -ErrorAction SilentlyContinue
#Copy-Item J:\Jenkins\userContent\CI\* -Destination . -Recurse -Force -ErrorAction SilentlyContinue
#endregion


#region PREPARE XML FILE
Write-Host "Injecting Azure Configuration data in $xmlConfigFileFinal file.."
[xml]$xmlFileData = [xml](Get-Content .\Azure_ICA_all.xml)
$xmlFileData.config.Azure.General.SubscriptionID = $xmlSecrets.secrets.SubscriptionID.Trim()
$xmlFileData.config.Azure.General.SubscriptionName = $xmlSecrets.secrets.SubscriptionName.Trim()
$xmlFileData.config.Azure.General.StorageAccount= $StorageAccountName
$xmlFileData.config.Azure.General.ARMStorageAccount = $StorageAccountName
$xmlFileData.config.Azure.Deployment.Data.Password = '"' + ($xmlSecrets.secrets.linuxTestPassword.Trim()) + '"'
$xmlFileData.config.Azure.Deployment.Data.UserName = $xmlSecrets.secrets.linuxTestUsername.Trim()
$xmlFileData.config.Azure.Deployment.Data.Distro[0].Name = ($DistroIdentifier).Trim()
$xmlFileData.config.Azure.General.AffinityGroup=""
$newNode = $xmlFileData.CreateElement("Location") 
$xmlFileData.config.Azure.General.AppendChild($newNode) | Out-Null
$xmlFileData.config.Azure.General.Location='"' + "$testLocation" + '"'
if ( $OsVHD )
{
    Write-Host "Injecting Os VHD Information in $xmlConfigFileFinal ..."    
    $xmlFileData.config.Azure.Deployment.Data.Distro[0].OsVHD = ($OsVHD).Trim()
}
else
{
    Write-Host "Injecting ARM Image Information in $xmlConfigFileFinal ..."    
    $armPub = ($ARMImageName).Split(" ")[0]
    $armOffer = ($ARMImageName).Split(" ")[1]
    $armSKU = ($ARMImageName).Split(" ")[2]
    $armVersion = ($ARMImageName).Split(" ")[3]
    $xmlFileData.config.Azure.Deployment.Data.Distro[0].ARMImage.Publisher = $armPub
    $xmlFileData.config.Azure.Deployment.Data.Distro[0].ARMImage.Offer = $armOffer
    $xmlFileData.config.Azure.Deployment.Data.Distro[0].ARMImage.Sku = $armSKU
    $xmlFileData.config.Azure.Deployment.Data.Distro[0].ARMImage.Version = $armVersion
}
#endregion

#region Inject DB data to XML

    $xmlFileData.config.Azure.database.server = ($xmlSecrets.secrets.DatabaseServer).Trim()
    $xmlFileData.config.Azure.database.user = ($xmlSecrets.secrets.DatabaseUser).Trim()
    $xmlFileData.config.Azure.database.password = ($xmlSecrets.secrets.DatabasePassword).Trim()
    $xmlFileData.config.Azure.database.dbname= ($xmlSecrets.secrets.DatabaseName).Trim()


if( $ResultDBTable )
{
    $xmlFileData.config.Azure.database.dbtable = ($ResultDBTable).Trim()
}
if( $ResultDBTestTag )
{
    $xmlFileData.config.Azure.database.testTag = ($ResultDBTestTag).Trim()
}
else
{
    #Write-Host "No Test Tag provided. If test needs DB support please fill testTag."
}
#endregion

$xmlFileData.Save("$xmlConfigFileFinal")
Write-Host "$xmlConfigFileFinal prepared successfully."

$currentDir = $PWD
Write-Host "CURRENT WORKING DIRECTORY - $currentDir"
& "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\ShortcutStartup.ps1"
Disable-AzureDataCollection
cd $currentDir


#region Generate trigger command
Remove-Item -Path ".\report\report_$(($TestCycle).Trim()).xml" -Force -ErrorAction SilentlyContinue

mkdir -Path .\tools -ErrorAction SilentlyContinue | Out-Null

if (!( Test-Path -Path .\tools\7za.exe ))
{
    Write-Host "Downloading 7za.exe"
    $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/7za.exe" -OutFile 7za.exe -ErrorAction SilentlyContinue | Out-Null
}
if (!( Test-Path -Path .\tools\dos2unix.exe ))
{
    Write-Host "Downloading dos2unix.exe"
    $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/dos2unix.exe" -OutFile dos2unix.exe -ErrorAction SilentlyContinue | Out-Null
}
if (!( Test-Path -Path .\tools\plink.exe ))
{
    Write-Host "Downloading plink.exe"
    $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/plink.exe" -OutFile plink.exe -ErrorAction SilentlyContinue | Out-Null
}
if (!( Test-Path -Path .\tools\pscp.exe ))
{
    Write-Host "Downloading pscp.exe"
    $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/pscp.exe" -OutFile pscp.exe -ErrorAction SilentlyContinue | Out-Null
}
Move-Item -Path "*.exe" -Destination .\tools -ErrorAction SilentlyContinue -Force


$cmd = ".\AzureAutomationManager.ps1 -runtests -Distro " + ($DistroIdentifier).Trim() + " -cycleName "+ ($TestCycle).Trim()
$cmd += " -xmlConfigFile $xmlConfigFileFinal"

if ( $OverrideVMSize )
{
    $cmd += " -OverrideVMSize $OverrideVMSize"
}
if ( $EconomyMode -eq "True")
{
    $cmd += " -EconomyMode -keepReproInact"
}
if ( $EnableAcceleratedNetworking )
{
    $cmd += " -EnableAcceleratedNetworking"
}
if ( $ForceDeleteResources )
{
    $cmd += " -ForceDeleteResources"
}

if ( $keepReproInact )
{
    $cmd += " -keepReproInact"
}
if ( $customKernel)
{
    $cmd += " -customKernel '$customKernel'"
}
if ( $customLIS)
{
    $cmd += " -customLIS $customLIS"
}
if ( $RunSelectedTests )
{
    $cmd += " -RunSelectedTests '$RunSelectedTests'"
}

$cmd += " -ImageType Standard"
$cmd += " -UseAzureResourceManager"

Write-Host "Invoking Final Command..."
Write-Host $cmd
Invoke-Expression -Command $cmd
Remove-Item *.json -Force

$LogDir = Get-Content .\report\lastLogDirectory.txt -ErrorAction SilentlyContinue
$currentDir = $PWD

function ZipFiles( $zipfilename, $sourcedir )
{
   cd $sourcedir
   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
        $zipfilename, $compressionLevel, $false)
}
Remove-Item -Path BuildLogs.zip -Force -ErrorAction SilentlyContinue
$retValue = 1
try
{
    if (Test-Path -Path ".\report\report_$(($TestCycle).Trim()).xml" )
    {
        Write-Host "Analysing results.."
        $resultXML = [xml](Get-Content ".\report\report_$(($TestCycle).Trim()).xml" -ErrorAction SilentlyContinue)
        if ( ( $resultXML.testsuites.testsuite.failures -eq 0 ) -and ( $resultXML.testsuites.testsuite.errors -eq 0 ) -and ( $resultXML.testsuites.testsuite.tests -gt 0 ))
        {
            $retValue = 0
        }
        else
        {
            $retValue = 1
        }
    }
}
catch
{
    Write-Host "$($_.Exception.GetType().FullName, " : ",$_.Exception.Message)"
    exit 1
}
finally
{
    if ( $finalWorkingDirectory )
    {
        Write-Host "Copying all files to original working directory."
        Copy-Item -Path "$finalWorkingDirectory\*" -Destination ('\\?\' + $originalWorkingDirectory) -Recurse -Force
    }    
    Write-Host "Exiting with code : $retValue"
    Remove-Item -Path $xmlConfigFileFinal
    exit $retValue
}
$retValue = 0
