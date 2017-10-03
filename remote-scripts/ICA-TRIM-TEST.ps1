# This script will deploy a VM and trigger the TRIM test.
#
# Author: Sivakanth Rebba
# Email : v-sirebb@microsoft.com
###################################################################################

Function CreateTestVMNode
{
	param(
            [string] $ServiceName,
			[string] $VIP,
			[string] $SSHPort,
			[string]  $username,
			[string] $password,
			[string] $DIP,
			[string] $DNSUrl,
			[string] $logDir )


	$objNode = New-Object -TypeName PSObject
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name ServiceName -Value $ServiceName -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name VIP -Value $VIP -Force 
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name SSHPort -Value $SSHPort -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name username -Value  $username -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name password -Value $password -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name DIP -Value $nodeDip -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name logDir -Value $LogDir -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name DNSURL -Value $DNSUrl -Force
	return $objNode
}

Function ParseLog($log)
{
    $text = Get-Content $log
    if ($text -match '^Failed.*0x[0-9A-F]{8}$')
    {
        "Error: VhdGetAs failed, please check the log at $log"
        return $null
    }
	else
	{
		$line = $text -match 'Actual/Billable Size: '
		$regex = [regex]'(\d+\s\w{5})'
		$APValue = $regex.match($line).Value
		$APValue = $APValue.split(" ")[0]
		return $APValue
	}
}
Function TrimSetup($VMObject, $PrevTestStatus, $metaData, $trimParam, $ISAbortIgnore="No")
{
	if ( $PrevTestStatus -eq "PASS" )
    {	
		LogMsg "STARTING TEST : $trimParam : $metaData"
		$BasicInfoCmds = "date^last^uname -r^uname -a^dmesg | grep -i 'Host Build'^cat /etc/*-release^df -hT^fdisk -l^cat /etc/fstab^hostname^python -V^waagent --version"
		$BasicInfoCmds = ($BasicInfoCmds).Split("^")
		Set-Content -Value "**************$BasicInfoCmd $metaData******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		foreach($BasicInfoCmd in $BasicInfoCmds)
		{
			Add-Content -Value "************** Status of $BasicInfoCmd******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
			$basic_VM_cmd_info_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $BasicInfoCmd -runAsSudo 
			Add-Content -Value $basic_VM_cmd_info_status -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		}
		$TrimSetupConsole = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "bash auto_rdos_XStoreTrim_setup.sh $($VMObject.username)" -runAsSudo -runMaxAllowedTime 1200 
		Set-Content -Value $TrimSetupConsole -Path "$($VMObject.logDir)\TrimSetupConsoleOutput.txt"
		$TrimSetupStatus = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "cat /home/$user/state.txt" -runAsSudo 
		if (($TrimSetupStatus -eq "TestCompleted") -or ($TrimSetupConsole -imatch "Updating test case state to completed"))
		{
			$ExitCode = "PASS"
			LogMsg "TrimSetup : $trimParam : $metaData COMPLETED"
		}
		elseif ( $TrimSetupStatus -eq "TestFailed" )
		{
			$ExitCode = "FAIL"
			LogMsg "TrimSetup : $trimParam : $metaData FAILED"
		}
		elseif ( $TrimSetupStatus -eq  "TestAborted" )
		{
			$ExitCode = "ABORTED"
			LogMsg "TrimSetup : $trimParam : $metaData ABORTED"
		}
	}
	elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $trimParam : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $trimParam : $metaData due to previous Aborted test"
    }
return $ExitCode
}

Function TrimTest($VMObject, $PrevTestStatus, $metaData, $trimParam, $ISAbortIgnore="No")
{
	if ( $PrevTestStatus -eq "PASS" )
    {	
		LogMsg "STARTING TEST : $trimParam : $metaData"
		$BasicInfoCmds = "date^last^uname -r^uname -a^dmesg | grep -i 'Host Build'^cat /etc/*-release^df -hT^fdisk -l^cat /etc/fstab^hostname^python -V^waagent --version"
		$BasicInfoCmds = ($BasicInfoCmds).Split("^")
		Set-Content -Value "**************$BasicInfoCmd $metaData******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		foreach($BasicInfoCmd in $BasicInfoCmds)
		{
			Add-Content -Value "************** Status of $BasicInfoCmd******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
			$basic_VM_cmd_info_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $BasicInfoCmd -runAsSudo -ignoreLinuxExitCode
			Add-Content -Value $basic_VM_cmd_info_status -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		}
		$testJob = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "bash auto_rdos_XStoreTrim.sh $($VMObject.username) >> TrimTestConsoleOutput.txt" -runAsSudo -RunInBackground
		#region MONITOR TEST
		while ( (Get-Job -Id $testJob).State -eq "Running" )
		{
			$currentStatus = RunLinuxCmd -ip $VMObject.VIP -port $VMObject.SSHPort -username $VMObject.username -password $VMObject.password -command "tail -2 TrimTestConsoleOutput.txt"
			LogMsg "Current Test Staus : $currentStatus"
			WaitFor -seconds 30
		}
		
		$TrimTestConsole = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "cat TrimTestConsoleOutput.txt" -runAsSudo
		Set-Content -Value $TrimTestConsole -Path "$($VMObject.logDir)\TrimTestConsoleOutput.txt"
		
		$testResult = GetActivePages -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData -trimParam $trimParam -StorageAccountName $StorageAccountName -StoragePrimaryKey $StoragePrimaryKey -vhdUrl $vhdUrl
		
		$testJob = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "bash auto_rdos_XStoreTrimFinal.sh $($VMObject.username) >> TrimTestConsoleOutput.txt" -runAsSudo -RunInBackground
		#region MONITOR TEST
		while ( (Get-Job -Id $testJob).State -eq "Running" )
		{
			$currentStatus = RunLinuxCmd -ip $VMObject.VIP -port $VMObject.SSHPort -username $VMObject.username -password $VMObject.password -command "tail -2 TrimTestConsoleOutput.txt"
			LogMsg "Current Test Staus : $currentStatus"
			WaitFor -seconds 30
		}
		$TrimTestConsole = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "cat TrimTestConsoleOutput.txt" -runAsSudo
		Add-Content -Value $TrimTestConsole -Path "$($VMObject.logDir)\TrimTestConsoleOutput.txt"
		
		$TestStatus = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "ls /home/$user | grep state.txt" -runAsSudo
		if ($TestStatus)
		{
			$TrimTestStatus = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "cat /home/$user/state.txt" -runAsSudo 
		}
		else
		{
			$TrimTestStatus = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "cat /root/state.txt" -runAsSudo 
		}
		
		if (($TrimTestStatus -eq "TestCompleted") -or ($TrimTestConsole -imatch "Updating test case state to completed"))
		{
			$ExitCode = "PASS"
			LogMsg "TrimTest : $trimParam : $metaData COMPLETED"
		}
		elseif ( $TrimTestStatus -eq "TestFailed" )
		{
			$ExitCode = "FAIL"
			LogMsg "TrimTest : $trimParam : $metaData FAILED"
		}
		elseif ( $TrimTestStatus -eq  "TestAborted" )
		{
			$ExitCode = "ABORTED"
			LogMsg "TrimTest : $trimParam : $metaData ABORTED"
		}
		elseif ( $TrimTestStatus -eq  "TestRunning" )
		{
			LogMsg "TrimTest : $trimParam : $metaData RUNNING"
		}
		else
		{
			LogMsg "TrimTest : $trimParam : $metaData ABORTED"
		}
	}
	elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $trimParam : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $trimParam : $metaData due to previous Aborted test"
    }
return $ExitCode
	
}

Function CompareActivePageResults($VMObject, $PrevTestStatus, $metaData, $trimParam, $APBefore, $APAfter, $ISAbortIgnore="No")
{
	LogMsg "STARTING TEST : $trimParam : $metaData"
	LogMsg "APBefore is $APBefore"
	LogMsg "APAfter is $APAfter"
	$APBeforeValue = [Float]::Parse($APBefore)
	$APAfterValue = [Float]::Parse($APAfter)
	if ($APBeforeValue * 0.95 -le $APAfterValue -and $APAfterValue -le $APBeforeValue * 1.05)
	{
		$ExitCode = "PASS"
		LogMsg "APAfterTrim is in between 95% - 105% of APBeforeTrim"
		LogMsg "CompareActivePageResults : $trimParam : $metaData COMPLETED"
	}
	else
	{
		$ExitCode = "FAIL"
		LogMsg "APAfterTrim is NOT in between 95% - 105% of APBeforeTrim"
		LogMsg "CompareActivePageResults : $trimParam : $metaData FAILED"
	}
return $ExitCode
}

Function GetActivePages($VMObject, $PrevTestStatus, $metaData, $trimParam, $StorageAccountName, $StoragePrimaryKey, $vhdUrl, $ISAbortIgnore="No")
{
    if ( $PrevTestStatus -eq "PASS" )
    {
        LogMsg "STARTING TEST : $trimParam : $metaData"
		$GetActivePagesJob = Start-Job -ScriptBlock { cd ".\tools\wazvhdsize-v1.1"; .\wazvhdsize.exe -name $args[0] -key $args[1] -uri $args[2] -env Global } -ArgumentList $StorageAccountName, $StoragePrimaryKey, $vhdUrl
		sleep -Seconds 20
		LogMsg "$GetActivePagesJob"
		$GetActivePagesJobStatus = Receive-Job -Id $GetActivePagesJob.Id
		Set-Content -Value "***** $metaData *****"-Path "$($VMObject.logDir)\ActivePages-$metaData.txt"
		Add-Content -Value $GetActivePagesJobStatus -Path "$($VMObject.logDir)\ActivePages-$metaData.txt"
		if ($GetActivePagesJobStatus -imatch "Calulation completed")
		{
			$ExitCode = "PASS"
			LogMsg "StorageAccountName : $StorageAccountName`n vhdUrl : $vhdUrl"
			LogMsg (Get-Content -Path "$($VMObject.logDir)\ActivePages-$metaData.txt")
			LogMsg "GetActivePages : $trimParam : $metaData COMPLETED"
			
		
			Remove-Job -Id $GetActivePagesJob.Id -Force -Verbose
		}
		else
		{
			$ExitCode = "FAIL"
			LogMsg "StorageAccountName : $StorageAccountName`n vhdUrl : $vhdUrl"
			LogMsg (Get-Content -Path "$($VMObject.logDir)\ActivePages-$metaData.txt")
			LogMsg "GetActivePages : $trimParam : $metaData FAILED"	
			Remove-Job -Id $GetActivePagesJob.Id -Force -Verbose
		}
	}
	elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $trimParam : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $trimParam : $metaData due to previous Aborted test"
    }	
return $ExitCode
}
Function PrepareVMForTrimTest ($VMObject, $DetectedDistro)
{
    if (( $DetectedDistro -imatch "CENTOS" ) -or ($DetectedDistro -imatch "REDHAT") -or ($DetectedDistro -imatch "ORACLE"))
    {
        LogMsg "Installing wget tar btrfs-progs xfsprogs"
		$out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install --nogpgcheck -y wget tar btrfs-progs xfsprogs" -runAsSudo
    }
    if (( $DetectedDistro -imatch "UBUNTU" ) -or ($DetectedDistro -imatch "DEBIAN"))
    {
        LogMsg "Installing wget tar btrfs-tools xfsprogs"
		$out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "apt-get install --force-yes -y wget tar btrfs-tools xfsprogs" -runAsSudo
    }
	if ( ($DetectedDistro -imatch "SLES") -or ($DetectedDistro -imatch "SUSE"))
    {
        LogMsg "Installing wget tar btrfsprogs xfsprogs"
		$out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "zypper --non-interactive install wget tar btrfsprogs xfsprogs" -runAsSudo
    }
}

Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests = $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
$StorageAccountName = $xmlConfig.config.Azure.General.ARMStorageAccount
$StoragePrimaryKey = $null
$diskType = $currentTestData.diskType
$ActivePageValueBeforeTrim = ""
$ActivePageValueAfterTrim = ""
Set-Variable -Name ActivePageValueBeforeTrim -Value $ActivePageValueBeforeTrim -Scope Global
Set-Variable -Name ActivePageValueAfterTrim -Value $ActivePageValueAfterTrim -Scope Global
Set-Variable -Name StorageAccountName -Value $StorageAccountName -Scope Global
Set-Variable -Name StoragePrimaryKey -Value $StoragePrimaryKey -Scope Global
$vhdUrl = ""
Set-Variable -Name vhdUrl -Value $vhdUrl -Scope Global
$result = ""
$testResult = ""
$resultArr = @()

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{
	$hs1VIP = $AllVMData.PublicIP
	$hs1vm1sshport = $AllVMData.SSHPort
	$hs1ServiceUrl = $AllVMData.URL
	$hs1vm1Dip = $AllVMData.InternalIP
	$instanceSize = $allVMData.InstanceSize
	$vhdUrl = (Get-AzureRmVM -ResourceGroupName $allVMData.ResourceGroupName).StorageProfile.DataDisks[0].Vhd.Uri
	
	$saInfoCollected = $false
	$retryCount = 0
	$maxRetryCount = 999
	while(!$saInfoCollected -and ($retryCount -lt $maxRetryCount))
	{
		
		try
			{
				$retryCount += 1
				LogMsg "[Attempt $retryCount/$maxRetryCount] : Getting Existing Storage Account : $StorageAccountName details ..."
				$GetAzureRMStorageAccount = $null
				$GetAzureRMStorageAccount = Get-AzureRmStorageAccount
				if ($GetAzureRMStorageAccount -eq $null)
				{
					throw
				}
				$StoragePrimaryKey = $($GetAzureRMStorageAccount | Where { $_.StorageAccountName -eq $StorageAccountName }  | Get-AzureRmStorageAccountKey)[0].Value 
				$saInfoCollected = $true            
			}
		catch
			{
				LogErr "Error in fetching Storage Account info. Retrying in 20 seconds."
				WaitFor -Seconds 20
			}
	} 
	
	$VMObject = CreateTestVMNode -ServiceName $isDeployed -VIP $hs1VIP -SSHPort $hs1vm1sshport -username  $user -password $password -DNSUrl $hs1ServiceUrl -logDir $LogDir
	$DetectedDistro = DetectLinuxDistro -VIP $hs1VIP -SSHport $hs1vm1sshport -testVMUser  $user -testVMPassword $password
	$out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "chmod +x *.sh" -runAsSudo
    $out = PrepareVMForTrimTest -VMObject $VMObject -DetectedDistro $DetectedDistro
	
	$trimParams = $currentTestData.TestParameters.param
	$trimParams = $trimParams.Replace("trimParam=",'').Replace("(","").Replace(")","").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace(" ",",").Replace('"',"")
	
	foreach ( $trimParam in $trimParams.split(","))
	{
		$testResult = "PASS"
		mkdir "$LogDir\$trimParam" -Force | Out-Null
		#region Get the info about the disks
		$fdiskOutput = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "$fdisk -l" -runAsSudo
		$allDetectedDisks = GetNewPhysicalDiskNames -FdiskOutputBeforeAddingDisk "Disk /dev/sda`nDisk /dev/sdb" -FdiskOutputAfterAddingDisk $fdiskOutput

		#/dev/sda is OS disk and and /dev/sdb is the resource disk. So we will count the disks from /dev/sdc.
		$detectedTestDisks = ""
		foreach ( $disk in $allDetectedDisks.split("^"))
		{
			if (( $disk -eq "/dev/sda") -or ($disk -eq "/dev/sdb"))
			{
				#SKIP adding the disk to detected test disk list.
			}
			else
			{
				if ( $detectedTestDisks )
				{
					$detectedTestDisks += "^" + $disk
				}
				else
				{
					$detectedTestDisks = $disk
				}
			}
		}
		#endregion
		$out = RemoteCopy -uploadTo $VMObject.VIP -port $VMObject.SSHPort -files $currentTestData.files -username $VMObject.username -password $VMObject.password -upload
		#region to generating constatnt.sh
		LogMsg "Generating constansts.sh ..."
		$constantsFile = ".\$LogDir\$trimParam\constants.sh"
		foreach ( $disk in $detectedTestDisks.split("^"))
		{
			$diskName = $disk.Split("/")[2]
			Add-Content -Value "DATA_DISK=$diskName" -Path $constantsFile
		}
		Add-Content -Value "trimParam=$trimParam" -Path $constantsFile
		LogMsg "trimParam=$trimParam added to constansts.sh"	
		LogMsg "constanst.sh created successfully..."
		LogMsg (Get-Content -Path $constantsFile)
		#endregion
		$out = RemoteCopy -uploadTo $VMObject.VIP -port $VMObject.SSHPort -files $constantsFile -username $VMObject.username -password $VMObject.password -upload
		
		
		foreach($TestID in $SubtestValues)
		{
			try
			{
				$PrevTestResult = $testResult
				$testResult = $null
				switch ($TestID.Trim())
				{
				"TestID1" #TrimSetup
					{
						$metaData = "Pass1 - $diskType Disk Trim setup"
						mkdir "$LogDir\$trimParam\$metaData" -Force | Out-Null
						$VMObject.LogDir = "$LogDir\$trimParam\$metaData"
						$testResult = TrimSetup -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData -trimParam $trimParam				
					}
					
				"TestID2" #Get ActivePages Before Trim test
					{
						$metaData = "Pass2 - $diskType Disk ActivePages Before Trim"
						mkdir "$LogDir\$trimParam\$metaData" -Force | Out-Null
						$VMObject.LogDir = "$LogDir\$trimParam\$metaData"
						$testResult = GetActivePages -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData -trimParam $trimParam -StorageAccountName $StorageAccountName -StoragePrimaryKey $StoragePrimaryKey -vhdUrl $vhdUrl
						$ActivePageValueBeforeTrim = ParseLog -log "$($VMObject.logDir)\ActivePages-$metaData.txt"
						$metaData = "$metaData : $ActivePageValueBeforeTrim "
					}
				"TestID3" #Trim Test
					{
						$metaData = "Pass3 - $diskType Disk ActivePages on Trim Test"
						mkdir "$LogDir\$trimParam\$metaData" -Force | Out-Null
						$VMObject.LogDir = "$LogDir\$trimParam\$metaData"
						$testResult = TrimTest -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData	-trimParam $trimParam
						$ActivePageValueOnTrim = ParseLog -log "$($VMObject.logDir)\ActivePages-$metaData.txt"
						$metaData = "$metaData : $ActivePageValueOnTrim "						
					}
				"TestID4" #Get ActivePages After Trim test
					{
						$metaData = "Pass4 - $diskType Disk ActivePages After Trim"
						mkdir "$LogDir\$trimParam\$metaData" -Force | Out-Null
						$VMObject.LogDir = "$LogDir\$trimParam\$metaData"
						$testResult = GetActivePages -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData -trimParam $trimParam -StorageAccountName $StorageAccountName -StoragePrimaryKey $StoragePrimaryKey -vhdUrl $vhdUrl
						$ActivePageValueAfterTrim = ParseLog -log "$($VMObject.logDir)\ActivePages-$metaData.txt"
						$metaData = "$metaData : $ActivePageValueAfterTrim "
					}
				 "TestID5" #Comparision of Active Pages Results before & after Trim test
					{
						$metaData = "Pass5 - $diskType Disk Comparision of Active Pages"
						mkdir "$LogDir\$trimParam\$metaData" -Force | Out-Null
						$VMObject.LogDir = "$LogDir\$trimParam\$metaData"
						$testResult = CompareActivePageResults -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData -trimParam $trimParam -APBefore $ActivePageValueBeforeTrim -APAfter $ActivePageValueAfterTrim
						$metaData = "$metaData : APAfterTrim is between 95% - 105% of APBeforeTrim"
					}
				}	
			}
			catch
			{
				$ErrorMessage =  $_.Exception.Message
				LogMsg "EXCEPTION : $ErrorMessage"   
			}
			Finally
			{
				if (!$testResult)
				{
					$testResult = "Aborted"
				}
				$resultArr += $testResult
				$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "$trimParam : $metaData" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
			} 
		}
	}
}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result,$resultSummary