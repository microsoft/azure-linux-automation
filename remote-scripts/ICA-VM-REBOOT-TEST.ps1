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
		$rebootCount = $($currentTestData.rebootCount)
		$count = 1
		$nextRestartMethod = "Restart"
		while ( $count -le $rebootCount )
		{
			$testResult = "FAIL"
			$currentLogDir = "$LogDir\Attempt-$count-$nextRestartMethod"
			$out = mkdir $currentLogDir -Force | Out-Null
			if ( $nextRestartMethod -eq "Restart" )
			{
				$currentRestartMethod = "Restart"
				$nextRestartMethod = "StopAndStart"
				LogMsg "[$count/$rebootCount] Restarting $($allVMData.RoleName) ..."
				$restartStatus = Restart-AzureRmVM -Name $allVMData.RoleName -ResourceGroupName $allVMData.ResourceGroupName
				$restartStatus = $restartStatus.Status
			}
			else
			{
				$currentRestartMethod = "StopAndStart"
				$nextRestartMethod = "Restart"
				LogMsg "[$count/$rebootCount] Step1. Stopping $($allVMData.RoleName) ..."
				$stopVMStauts = Stop-AzureRmVM -Name $allVMData.RoleName -ResourceGroupName $allVMData.ResourceGroupName -Force -StayProvisioned
				if ( $stopVMStauts.Status -eq "Succeeded" )
				{
					LogMsg "[$count/$rebootCount] Step2. Starting $($allVMData.RoleName) ..."
					$startVMStautus = Start-AzureRmVM -Name $allVMData.RoleName -ResourceGroupName $allVMData.ResourceGroupName
					if ( $startVMStautus.Status -eq "Succeeded" )
					{
						$restartStatus = $startVMStautus.Status
					}
					else
					{
						$restartStatus = "Failed"
					}
				}
				else
				{
					$restartStatus = "Failed"
				}
			}
			if ( $restartStatus -eq "Succeeded" )
			{
				LogMsg "VM restarted successfully"
				LogMsg "Sleeping 10 seconds ..."
				WaitFor -seconds 10
				$sshStatus = isAllSSHPortsEnabledRG -AllVMDataObject $AllVMData
				if ( $sshStatus -eq "True" )
				{
					LogMsg "SSH connection verified"
					$out = RunLinuxCmd -ip $($allVMData.PublicIP) -port $($allVMData.SSHPort) -username $user -password $password -command "dmesg > /home/$user/InitialBootLogs.txt" -runAsSudo
					$out = RemoteCopy -download -downloadFrom $($allVMData.PublicIP) -port $($allVMData.SSHPort) -files "/home/$user/InitialBootLogs.txt" -downloadTo $currentLogDir -username $user -password $password
					LogMsg "$($allVMData.RoleName) : Kernel logs collected .."
					LogMsg "Checking for call traces in kernel logs.."
					$KernelLogs = Get-Content "$currentLogDir\InitialBootLogs.txt"
					$callTraceFound  = $false
					foreach ( $line in $KernelLogs )
					{
						if ( $line -imatch "Call Trace" )
						{
							LogErr $line
							$callTraceFound = $true
						}
						if ( $callTraceFound )
						{
							if ( $line -imatch "\[<")
							{
								LogErr $line
							}
						}
					}
					if ( !$callTraceFound )
					{
						LogMsg "No any call traces found."
						$testResult = "PASS"
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "$count : $currentRestartMethod" -checkValues "PASS,FAIL,ABORTED" -testName "$($currentTestData.testName)"
					}
					else
					{
						LogErr "call traces found."
						$testResult = "FAIL"
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "$count : $currentRestartMethod" -checkValues "PASS,FAIL,ABORTED" -testName "$($currentTestData.testName)"
						break
					}

					$count += 1
				}
				else
				{
					LogErr "SSH connection failed."
					$testResult = "FAIL"
					$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "$count : $currentRestartMethod" -checkValues "PASS,FAIL,ABORTED" -testName "$($currentTestData.testName)"
					break
				}
			}
			else
			{
				LogErr "Failed to restart VM"
				$testResult = "FAIL"
				$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "$count : $currentRestartMethod" -checkValues "PASS,FAIL,ABORTED" -testName "$($currentTestData.testName)"
				break
			}
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