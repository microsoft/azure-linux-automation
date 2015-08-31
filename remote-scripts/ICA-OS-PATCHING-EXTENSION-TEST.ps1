<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
		$hs1vm1Hostname = $AllVMData.RoleName
		$ExtensionVerfiedWithPowershell = $false
		$lsOutput = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls /var/log/" -runAsSudo
		LogMsg -msg $lsOutput -LinuxConsoleOuput
		$varLogFolder = "/var/log"
		$lsOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls -lR $varLogFolder" -runAsSudo
		$LogFilesPaths = ""
		$LogFiles = ""
		$folderToSearch = "/var/log/azure"
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod -R 666 $varLogFolder" -runAsSudo
		WaitFor -Seconds 120
		foreach ($line in $lsOut.Split("`n") )
		{
			$line = $line.Trim()
			if ($line -imatch $varLogFolder)
			{
				$currentFolder = $line.Replace(":","")
			}
			if ( ( ($line.Split(" ")[0][0])  -eq "-" ) -and ($currentFolder -imatch $folderToSearch) )
			{
				$currentLogFile = $line.Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[8]
				if ($LogFilesPaths)
				{
					$LogFilesPaths += "," + $currentFolder + "/" + $currentLogFile
					$LogFiles += "," + $currentLogFile
				}
				else
				{
					$LogFilesPaths = $currentFolder + "/" + $currentLogFile
					$LogFiles += $currentLogFile
				}
			}
		}
		$retryCount = 1
		$maxRetryCount = 20
		if ($LogFilesPaths)
		{   
			do
			{   LogMsg "Attempt : $retryCount/$maxRetryCount : Checking extension log files...."
				foreach ($file in $LogFilesPaths.Split(","))
				{
					foreach ($fileName in $LogFiles.Split(","))
					{
						if ( $file -imatch $fileName )
						{
							$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $file > $fileName" -runAsSudo
							RemoteCopy -download -downloadFrom $hs1VIP -files $fileName -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
						}
					}
				}
				if ( Test-Path "$LogDir\extension.log" )
				{
					$extensionOutput = Get-Content -Path $LogDir\extension.log
					$waitForExtension = $false
					#Check for the patch list
					foreach ($line in $extensionOutput.Split("`n"))
					{
						if ($patchListNotAvailable)
						{ 
							if ( $line -imatch "Patch list:" )
							{
								$patchList = $line.Trim()
								$patchListNotAvailable = $false
							}
						}
						else
						{
							$patchListNotAvailable = $true

						}
						if ($line -imatch "Start to install \d patches")
						{
							$totalPackages = $line.Trim().replace("[","").replace("]","").Split()[5]
						}
					}
					if ( $patchListNotAvailable )
					{
						LogMsg "No packages scheduled to update."
						$extensionVerified = $true
						
					}
					else
					{
						LogMsg "Total Update Packages : $totalPackages"
						LogMsg "Packages to be udpated by extension : "
						$patchList = $patchList.Split()
						$patchListCount = $patchList.Count
						for ( $i = 0; $i -le ($totalPackages) ; $i++ )
						{
						   LogMsg $patchList[($patchListCount-$i)]
						}
						$extensionVerified = $true
					}
					$waitForExtension = $false
				}
				else
				{
					$extensionVerified = $false
					LogErr "extension.log file does not present"
					$waitForExtension = $true
					$retryCount += 1
					WaitFor -Seconds 30
				}
			}
			while (($retryCount -lt $maxRetryCount) -and $waitForExtension )
		}
		else
		{
			LogErr "No Extension logs are available."
			$extensionVerified = $false
		}
		$vmDetails = Get-AzureVM -ServiceName $isDeployed
 		if ( ( $vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Status -eq "Success" ) -and ($vmDetails.ResourceExtensionStatusList.ExtensionSettingStatus.Name -imatch "OSPatchingForLinux" ))
		{
			$ExtensionVerfiedWithPowershell = $true
			LogMsg "OSPatchingForLinux extension status is SUCCESS in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
		}
		else
		{
			$ExtensionVerfiedWithPowershell = $false
			LogErr "OSPatchingForLinux extension status is FAILED in (Get-AzureVM).ResourceExtensionStatusList.ExtensionSettingStatus"
		}
		if ( $ExtensionVerfiedWithPowershell -and $extensionVerified )
		{
			$testResult = "PASS"
		}
		else
		{
			$testResult = "FAIL"
		}
		LogMsg "Test result : $testResult"
	}

	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = ""
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result
