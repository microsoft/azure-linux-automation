# This script deploys the VMs for the IO performance test and trigger the test.
# 1. sysstat sysbench mdadm lvm lvm2 and dos2unix must be installed in the test image
# Author: Sivakanth R
# Email	: v-sirebb@microsoft.com
#
#####

<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$DiskType = ""

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

if ($isDeployed)
{
	try
	{
		$allVMData  = GetAllDeployementData -DeployedServices $isDeployed
		Set-Variable -Name AllVMData -Value $allVMData
		$hs1VIP = $allVMData.PublicIP
		$hs1ServiceUrl = $allVMData.URL
		$hs1vm1IP = $allVMData.InternalIP
		$hs1vm1Hostname = $allVMData.RoleName
		$hs1vm1sshport = $allVMData.SSHPort
		$hs1vm1tcpport = $allVMData.TCPtestPort
		$hs1vm1udpport = $allVMData.UDPtestPort
		$DiskType = $currentTestData.DiskType
		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mkdir code" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cp *.sh code/" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x code/*" -runAsSudo
		
		$KernelVersion = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo 
		LogMsg "VM1 kernel version:- $KernelVersion"
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "yum install -y lvm2" -runAsSudo 
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash /home/$user/code/$($currentTestData.testScript) $user $DiskType" -runAsSudo -runmaxallowedtime 7200
		$iosetupStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/iotest.log.txt | grep 'mount: Success'" -runAsSudo
		if ($iosetupStatus -imatch 'mount: Success')
		{
			LogMsg "$DiskType is created Successfully and VM is ready for IOPerf test"
			$restartvmstatus = RestartAllDeployments -allVMData $allVMData
			
			if ($restartvmstatus -eq "True")
			{
				LogMsg "VMs Restarted Successfully"
				WaitFor -seconds 120
				$sysbenchStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/sysbenchlog/sysbench.log.txt | grep 'Starting Run'" -runAsSudo
				if ($sysbenchStatus -imatch "Starting Run")
				{
					LogMsg "Sysbench started creating files for io test.."
					
					for($testDuration -le 260000)
					{
						$sysbenchStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "pgrep sysbench 2>/dev/null" -runAsSudo -ignoreLinuxExitCode
						if ($sysbenchStatus)
						{
							$iterationStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "grep iteration /home/$user/code/sysbenchlog/sysbench.log.txt | tail -1" -runAsSudo -ignoreLinuxExitCode
							LogMsg "Sysbench test is RUNNING.. `n $iterationStatus"
						}
						else{
							
							WaitFor -seconds 30
							$sysbenchStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "pgrep sysbench 2>/dev/null" -runAsSudo -ignoreLinuxExitCode
							if ($sysbenchStatus)
							{
								$iterationStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "grep iteration /home/$user/code/sysbenchlog/sysbench.log.txt | tail -1" -runAsSudo -ignoreLinuxExitCode
								LogMsg "Sysbench test is RUNNING.. `n $iterationStatus"
							}
							else{
								$iotestStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/sysbenchlog/sysbench.log.txt | grep 'SYSBENCH TEST COMPLETED' " -runAsSudo
								if ($iotestStatus -imatch "SYSBENCH TEST COMPLETED")
								{
									LogMsg "Sysbench test is COMPLETED.."
									$testResult = "PASS"
									WaitFor -seconds 30
									$logparserStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command " cat /home/$user/code/sysbenchlog/sysbench.log.txt | grep 'LOGPARSER COMPLETED' " -runAsSudo -ignoreLinuxExitCode
 									
									if ($logparserStatus -imatch "LOGPARSER COMPLETED")
									{
										LogMsg "IO perf test and its log parser is COMPLETED.."	
										$testResult = "PASS"
										$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/*.tar" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
										break
									}
									else{
										LogMsg "IO perf test is  COMPLETED.. and its log parser is FAILED.."
										LogMsg "Check Log Parser and run it manully to generate .csv file"	
										$testResult = "PASS"
										$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/*.tar" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
										break
									}								
								}
								else{
									LogMsg "Sysbench test is ABORTED.."
									$testResult = "Aborted"
									Break
								}
							}
						}
						WaitFor -seconds 300
						$testDuration=$testDuration+300
					}
				}
			}
			else{
				LogMsg "VMs Restarts Failed.."
				$testResult = "Aborted"
			}
		}
		else{
			LogErr "$DiskType creation is FAILED.. and IOPerf test is ABORTED"
			$testResult = "Aborted"
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
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
