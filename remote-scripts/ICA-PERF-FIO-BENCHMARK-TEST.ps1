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
		$clientVMData = $allVMData

		#region Get the info about the disks
		$fdiskOutput = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "$fdisk -l" -runAsSudo
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
		
		LogMsg "Generating constansts.sh ..."
		$constantsFile = ".\$LogDir\constants.sh"
		foreach ( $disk in $detectedTestDisks.split("^"))
		{
			Add-Content -Value "testdisk=$disk" -Path $constantsFile
		}
		foreach ($testParam in $currentTestData.TestParameters.param )
		{
			Add-Content -Value "$testParam" -Path $constantsFile
			LogMsg "$testParam added to constansts.sh"
		}
		
		LogMsg "constanst.sh created successfully..."
        LogMsg (Get-Content -Path $constantsFile)
		#endregion
						
		#region EXECUTE TEST
		Set-Content -Value "/root/performance_middleware_fio.sh &> FioConsoleLogs.txt" -Path "$LogDir\StartFioTest.sh"
		RemoteCopy -uploadTo $clientVMData.PublicIP -port $clientVMData.SSHPort -files ".\$constantsFile,.\remote-scripts\performance_middleware_fio.sh,.\$LogDir\StartFioTest.sh" -username "root" -password $password -upload

		$out = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "chmod +x *.sh" #-runAsSudo
		$testJob = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "/root/StartFioTest.sh" -RunInBackground
		#endregion

		#region MONITOR TEST
		while ( (Get-Job -Id $testJob).State -eq "Running" )
		{
			$currentStatus = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "tail -n 1 /root/FioConsoleLogs.txt"
			$currentfioStatus = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "tail -n 1 /root/FIOLog/fio-test.log.txt" -ignoreLinuxExitCode
			LogMsg "Current Test Staus : $currentStatus `n$currentfioStatus"
			WaitFor -seconds 20
		}
		
		$finalStatus = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "cat /root/state.txt"
		RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "FioConsoleLogs.txt,state.txt,summary.log"
        
		## add here code for display results
        
		if ( $finalStatus -imatch "TestFailed")
		{
			LogErr "Test failed. Last known status : $currentStatus."
			$testResult = "FAIL"
		}
		elseif ( $finalStatus -imatch "TestAborted")
		{
			LogErr "Test Aborted. Last known status : $currentStatus."
			$testResult = "ABORTED"
		}
		elseif ( $finalStatus -imatch "TestCompleted")
		{
			LogMsg "Test Completed."
			$testResult = "PASS"
			
			$fioLogDir = "$LogDir\FIOLog"
			mkdir $fioLogDir -Force | Out-Null
			mkdir $fioLogDir\jsonLog -Force | Out-Null
			RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $fioLogDir\jsonLog -files "FIOLog/jsonLog/*"
			mkdir $fioLogDir\iostatLog -Force | Out-Null
			RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $fioLogDir\iostatLog  -files "FIOLog/iostatLog/*"
			mkdir $fioLogDir\vmstatLog -Force | Out-Null
			RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $fioLogDir\vmstatLog -files "FIOLog/vmstatLog/*"
			mkdir $fioLogDir\sarLog -Force | Out-Null
			RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $fioLogDir\sarLog -files "FIOLog/sarLog/*"
			RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $fioLogDir -files "FIOLog/fio-test.log.txt"
		}
		elseif ( $finalStatus -imatch "TestRunning")
		{
			$testResult = "PASS"
		}
		LogMsg "Test result : $testResult"
		LogMsg "Test Completed"
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
		$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
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
return $result, $resultSummary