<#
.SYNOPSIS
  This script fetches kernel boot time and WALA provision.

.DESCRIPTION
  This script fetches kernel boot time and WALA provision time by -
    1. Downloading dmesg and waagent.log files from VM.
    2. Parsing the log files to calculate the data.

.PARAMETER -DeploymentTime
    Type: integer
    Required: Yes.

.PARAMETER -allVMData
    Type: PSObject
    Required: Yes.

.PARAMETER -customSecretsFilePath
    Type: string
    Required: Optinal.

.INPUTS
    AzureSecrets.xml file. If you are running this script in Jenkins, then make sure to add a secret file with ID: Azure_Secrets_File
    If you are running the file locally, then pass secrets file path to -customSecretsFilePath parameter.

.NOTES
    Version:        1.0
    Author:         Shital Savekar <v-shisav@microsoft.com>
    Creation Date:  14th December 2017
    Purpose/Change: Initial script development

.EXAMPLE
    .\UploadDeploymentDataToDB.ps1 -customSecretsFilePath .\AzureSecrets.xml
#>

param
(
    $DeploymentTime,
    $allVMData,
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

    $SubscriptionID = $xmlSecrets.secrets.SubscriptionID
    $SubscriptionName = $xmlSecrets.secrets.SubscriptionName
    $dataSource = $xmlSecrets.secrets.DatabaseServer
    $dbuser = $xmlSecrets.secrets.DatabaseUser
    $dbpassword = $xmlSecrets.secrets.DatabasePassword
    $database = $xmlSecrets.secrets.DatabaseName
    $dataTableName = "LinuxAzureDeploymentAndBootData"
    $storageAccountName = $xmlSecrets.secrets.bootPerfLogsStorageAccount
    $storageAccountKey = $xmlSecrets.secrets.bootPerfLogsStorageAccountKey

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
    $NumberOfVMsInRG = 0
    foreach ( $vmData in $allVMData )
    {
        $NumberOfVMsInRG += 1
    }

    $SQLQuery = "INSERT INTO $dataTableName (DateTimeUTC,SubscriptionID,SubscriptionName,ResourceGroupName,NumberOfVMsInRG,RoleName,DeploymentTime,KernelBootTime,WALAProvisionTime,HostVersion,GuestDistro,KernelVersion,LISVersion,WALAVersion,Region,RoleSize,StorageType,TestCaseName,CallTraces,kernelLogFile,WALAlogFile) VALUES "

    foreach ( $vmData in $allVMData )
    {

        $ResourceGroupName = $vmData.ResourceGroupName
        $RoleName = $vmData.RoleName
        $DeploymentTime = $DeploymentTime
        $Region = $vmData.Location
        $RoleSize = $vmData.InstanceSize
        $TestCaseName = $CurrentTestData.testName
        $StorageType = $StorageAccountTypeGlobal


        #Copy and run test file
        $out = RemoteCopy -upload -uploadTo $vmData.PublicIP -port $vmData.SSHPort -files .\remote-scripts\CollectLogFile.sh -username $user -password $password
        $out = RunLinuxCmd -username $user -password $password -ip $vmData.PublicIP -port $vmData.SSHPort -command "bash CollectLogFile.sh" -ignoreLinuxExitCode


        #download the log files
        $out = RemoteCopy -downloadFrom $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -files "$($vmData.RoleName)-*.txt" -downloadTo "$LogDir" -download

        # Upload files in data subfolder to Azure.
        $destfolder = "bootPerf"
        $containerName = "logs"
        $blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

        $ticks = (Get-Date).Ticks
        $fileName = "$LogDir\$($vmData.RoleName)-waagent.log.txt"
        $blobName = "$destfolder/$($fileName.Replace("waagent","waagent-$ticks") | Split-Path -Leaf)"
        $out = Set-AzureStorageBlobContent -File $filename -Container $containerName -Blob $blobName -Context $blobContext -Force
        $WALAlogFile = "https://$storageAccountName.blob.core.windows.net/$containerName/$destfolder/$($fileName.Replace("waagent","waagent-$ticks") | Split-Path -Leaf)"
        Write-Host "Upload file to Azure: Success: $WALAlogFile"
        $fileName = "$LogDir\$($vmData.RoleName)-dmesg.txt"
        $blobName = "$destfolder/$($fileName.Replace("dmesg","dmesg-$ticks") | Split-Path -Leaf)"
        $out = Set-AzureStorageBlobContent -File $filename -Container $containerName -Blob $blobName -Context $blobContext -Force
        $kernelLogFile = "https://$storageAccountName.blob.core.windows.net/$containerName/$destfolder/$($fileName.Replace("dmesg","dmesg-$ticks") | Split-Path -Leaf)"
        Write-Host "Upload file to Azure: Success: $kernelLogFile"
        $walaStartIdentifier = "Azure Linux Agent Version"
        $walaEndIdentifier = "Start env monitor service"
        $walaDistroIdentifier = "INFO OS"

        #Analyse

        #region Waagent Version Checking.
        $waagentFile = "$LogDir\$($vmData.RoleName)-waagent.log.txt"
        $waagentStartLineNumber = (Select-String -Path $waagentFile -Pattern "$walaStartIdentifier")[0].LineNumber
        $waagentStartLine = (Get-Content -Path $waagentFile)[$waagentStartLineNumber - 1]
        $WALAVersion = ($waagentStartLine.Split(":")[$waagentStartLine.Split(":").Count - 1]).Trim()
        Write-Host "$($vmData.RoleName) - WALA Version = $WALAVersion"
        #endregion

        if ( ($WALAVersion -imatch "2.2.18") -or ($WALAVersion -imatch "2.2.14") )
        {
            $walaEndIdentifier = "Provisioning complete"
        }

        if ($WALAVersion -imatch "2.2.17")
        {
            $walaEndIdentifier = "Finished provisioning"
        }
        if ($WALAVersion -imatch "2.0.16")
        {
            $walaEndIdentifier = "Provisioning image completed"
            $walaDistroIdentifier = "Linux Distribution Detected"
            $walaStartIdentifier = "Azure Linux Agent Version"
        }
        #region Guest Distro Checking
        $GuestDistro = Get-Content -Path "$LogDir\$($vmData.RoleName)-distroVersion.txt"
        Write-Host "$($vmData.RoleName) - GuestDistro = $GuestDistro"
        Set-Variable -Name GuestDistro -Value $GuestDistro -Scope Global
        #endregion



        #region Waagent Provision Time Checking.
        $waagentFile = "$LogDir\$($vmData.RoleName)-waagent.log.txt"
        $waagentStartLineNumber = (Select-String -Path $waagentFile -Pattern "$walaStartIdentifier")[0].LineNumber
        $waagentStartLine = (Get-Content -Path $waagentFile)[$waagentStartLineNumber - 1]
        $waagentStartTime = [datetime]$waagentStartLine.Split(".")[0]

        $waagentFinishedLineNumber = (Select-String -Path $waagentFile -Pattern "$walaEndIdentifier")[0].LineNumber
        $waagentFinishedLine = (Get-Content -Path $waagentFile)[$waagentFinishedLineNumber - 1]
        $waagentFinishedTime = [datetime]$waagentFinishedLine.Split(".")[0]

        $WALAProvisionTime = [int]($waagentFinishedTime - $waagentStartTime).TotalSeconds
        Write-Host "$($vmData.RoleName) - WALA Provision Time = $WALAProvisionTime"
        #endregion

        #region Boot Time checking.
        $bootStart = [datetime](Get-Content "$LogDir\$($vmData.RoleName)-uptime.txt")

        $kernelBootTime = ($waagentStartTime - $bootStart).TotalSeconds
        if ($kernelBootTime -le 0 -and $kernelBootTime -gt 1800)
        {
            Throw "Invalid boottime range. Boot time = $kernelBootTime"
        }
        $dmesgFile = "$LogDir\$($vmData.RoleName)-dmesg.txt"
        #$foundLineNumber = (Select-String -Path $dmesgFile -Pattern "$bootIdentifier").LineNumber
        #$actualLineNumber = $foundLineNumber - 2
        #$finalLine = (Get-Content -Path $dmesgFile)[$actualLineNumber]
        #Write-Host $finalLine
        #$KernelBootTime =  [math]::Round(($finalLine.Split("]")[0].Replace("[","").Trim()),2)
        Write-Host "$($vmData.RoleName) - Kernel Boot Time = $kernelBootTime seconds"
        #
        #endregion


        #region Call Trace Checking
		$KernelLogs = Get-Content $dmesgFile
		$callTraceFound  = $false
		foreach ( $line in $KernelLogs )
		{
			if ( $line -imatch "Call Trace" )
			{
				$callTraceFound = $true
			}
		}
		if ( $callTraceFound )
		{
			$CallTraces = "Yes"
		}
        else
        {
            $CallTraces = "No"
        }
        #endregion

        #region Host Version checking
        $foundLineNumber = (Select-String -Path $dmesgFile -Pattern "Hyper-V Host Build").LineNumber
        $actualLineNumber = $foundLineNumber - 1
        $finalLine = (Get-Content -Path $dmesgFile)[$actualLineNumber]
        #Write-Host $finalLine
        $finalLine = $finalLine.Replace('; Vmbus version:4.0','')
        $finalLine = $finalLine.Replace('; Vmbus version:3.0','')
        $HostVersion = ($finalLine.Split(":")[$finalLine.Split(":").Count -1 ]).Trim().TrimEnd(";")
        Write-Host "$($vmData.RoleName) - Host Version = $HostVersion"
        Set-Variable -Value $HostVersion -Name HostVersion -Scope Global 
        #endregion

        #region LIS Version
        $LISVersion = (Select-String -Path "$LogDir\$($vmData.RoleName)-lis.txt" -Pattern "^version:").Line
        if ($LISVersion)
        {
            $LISVersion = $LISVersion.Split(":").Trim()[1]
        }
        else
        {
            $LISVersion = "NA"
        }
        #endregion
        #region KernelVersion checking
        $KernelVersion = Get-Content "$LogDir\$($vmData.RoleName)-kernelVersion.txt"
        #endregion
        $SQLQuery += "('$DateTimeUTC','$SubscriptionID','$SubscriptionName','$ResourceGroupName','$NumberOfVMsInRG','$RoleName',$DeploymentTime,$KernelBootTime,$WALAProvisionTime,'$HostVersion','$GuestDistro','$KernelVersion','$LISVersion','$WALAVersion','$Region','$RoleSize','$StorageType','$TestCaseName','$CallTraces','$kernelLogFile','$WALAlogFile'),"
    }
    $SQLQuery = $SQLQuery.TrimEnd(',')
    $connectionString = "Server=$dataSource;uid=$dbuser; pwd=$dbpassword;Database=$database;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    LogMsg $SQLQuery

    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = $SQLQuery
    $result = $command.executenonquery()
    $connection.Close()

    LogMsg "Uploading boot data to database :  done!!"
}
catch
{
    $line = $_.InvocationInfo.ScriptLineNumber
    $script_name = ($_.InvocationInfo.ScriptName).Replace($PWD,".")
    $ErrorMessage =  $_.Exception.Message
    LogErr "EXCEPTION : $ErrorMessage"
    LogErr "Source : Line $line in script $script_name."
    LogErr "ERROR : Uploading boot data to database"
    LogMsg $SQLQuery
}