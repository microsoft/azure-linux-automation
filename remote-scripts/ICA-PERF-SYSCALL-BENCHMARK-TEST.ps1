# This script deploys the VM for the SYSCALL BENCHMARK test and trigger the test.
#
# Author: Maruthi Sivakanth Rebba
# Email: v-sirebb@microsoft.com
###################################################################################
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
		$testVMData = $allVMData
		ProvisionVMsForLisa -allVMData $allVMData -installPackagesOnRoleNames "none"
		
		#region EXECUTE TEST
		$myString = @"
cd /root/
chmod +x perf_syscallBenchmark.sh
./perf_syscallBenchmark.sh &> syscallConsoleLogs.txt
. azuremodules.sh
collect_VM_properties
"@

		Set-Content "$LogDir\StartSysCallBenchmark.sh" $myString		
		RemoteCopy -uploadTo $testVMData.PublicIP -port $testVMData.SSHPort -files ".\remote-scripts\azuremodules.sh,.\remote-scripts\perf_syscallBenchmark.sh,.\$LogDir\StartSysCallBenchmark.sh" -username "root" -password $password -upload

		$out = RunLinuxCmd -ip $testVMData.PublicIP -port $testVMData.SSHPort -username "root" -password $password -command "chmod +x *.sh" -runAsSudo
		$testJob = RunLinuxCmd -ip $testVMData.PublicIP -port $testVMData.SSHPort -username "root" -password $password -command "./StartSysCallBenchmark.sh" -RunInBackground -runAsSudo
		#endregion

		#region MONITOR TEST
		while ( (Get-Job -Id $testJob).State -eq "Running" )
		{
			$currentStatus = RunLinuxCmd -ip $testVMData.PublicIP -port $testVMData.SSHPort -username "root" -password $password -command "tail -1 syscallConsoleLogs.txt"-runAsSudo
			LogMsg "Current Test Staus : $currentStatus"
			WaitFor -seconds 10
		}
		$finalStatus = RunLinuxCmd -ip $testVMData.PublicIP -port $testVMData.SSHPort -username "root" -password $password -command "cat state.txt"
		$testSummary = $null
		#endregion

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
			RemoteCopy -downloadFrom $testVMData.PublicIP -port $testVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "syscall-benchmark-*.tar.gz"
			RemoteCopy -downloadFrom $testVMData.PublicIP -port $testVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "*.txt,*.log,*.csv"
			LogMsg "Test Completed."
			$testResult = "PASS"
		}
		elseif ( $finalStatus -imatch "TestRunning")
		{
			LogMsg "Powershell backgroud job for test is completed but VM is reporting that test is still running. Please check $LogDir\zkConsoleLogs.txt"
			LogMsg "Contests of summary.log : $testSummary"
			$testResult = "PASS"
		}
		
		try {
			$logFilePath = "$LogDir\results.log"
			$logs = Get-Content -Path $logFilePath
			$vmInfo = Get-Content -Path $logFilePath | select -First 2
			$logs = $logs.Split("`n")

			Function GetResultObject ()
			{
				$Object = New-Object PSObject                                       
				$Object | add-member -MemberType NoteProperty -Name test -Value $null
				$Object | add-member -MemberType NoteProperty -Name avgReal -Value $null
				$Object | add-member -MemberType NoteProperty -Name avgUser -Value $null
				$Object | add-member -MemberType NoteProperty -Name avgSystem -Value $null
				return $Object
			}
			$mode = $null
			$finalResult = @()
			$finalResult += "********************************************************"
			$finalResult += " 	SYSCALL BENCHMARK TEST RESULTS 	"
			$finalResult += "***************************************************************************************"
			$finalResult += $vmInfo
			$currentResult = GetResultObject

			foreach ($line in $logs)
			{
				if ( $line -imatch "bench_00_null_call_regs")
				{
					$currentResult.test = "bench_00_null_call_regs" 
				}
				elseif ( $line -imatch "bench_01_null_call_stack")
				{
					$currentResult.test = "bench_01_null_call_stack"  
				}
				elseif ( $line -imatch "bench_02_getpid_syscall")
				{
					$currentResult.test = "bench_02_getpid_syscall"  
				}
				if ( $line -imatch "bench_03_getpid_vdso")
				{
					$currentResult.test = "bench_03_getpid_vdso"
				}
				elseif ( $line -imatch "bench_10_read_syscall")
				{
					$currentResult.test = "bench_10_read_syscall"        
				}
				elseif ( $line -imatch "bench_11_read_vdso")
				{
					$currentResult.test = "bench_11_read_vdso"
				}
				elseif ( $line -imatch "bench_12_read_stdio")
				{
					$currentResult.test = "bench_12_read_stdio"       
				}
				elseif ( $line -imatch "bench_20_write_syscall")
				{
					$currentResult.test = "bench_20_write_syscall"        
				}
				elseif ( $line -imatch "bench_21_write_vdso")
				{
					$currentResult.test = "bench_21_write_vdso"  
				}
				elseif ( $line -imatch "bench_22_write_stdio")
				{
					$currentResult.test = "bench_22_write_stdio"        
				}
				elseif ( $line -imatch "average")
				{
					$testType = $currentResult.test
					$currentResult.avgReal = $avgReal = $line.Split(" ")[2]
					$currentResult.avgUser = $avgUser = $line.Split(" ")[4]
					$currentResult.avgSystem = $avgSystem = $line.Split(" ")[6]
					$finalResult += $currentResult
					$metadata = "test=$testType"
					$syscallResult = "AverageReal=$avgReal AverageUser=$avgUser AverageSystem=$avgSystem"
					$resultSummary +=  CreateResultSummary -testResult "$syscallResult : Completed" -metaData $metadata -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
					if ( $currentResult.test -imatch "bench_22_write_stdio")
					{
						LogMsg "Syscall results parsing is Done..."
						break
					}
					$currentResult = GetResultObject
				}
				else{
					continue
				}
			}			
			Set-Content -Value $finalResult -Path "$LogDir\syscalResults.txt"
			LogMsg ($finalResult | Format-Table | Out-String)			
		}
		catch{
			$ErrorMessage =  $_.Exception.Message
			LogMsg "EXCEPTION : $ErrorMessage"  
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
		$metaData = "SYSCALL BENCHMARK RESULT"
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
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
