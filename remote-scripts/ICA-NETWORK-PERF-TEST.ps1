# This script deploys the VMs for the network performance test and trigger test.
# Author: Sivakanth
# Email	: v-sirebb@microsoft.com
#
#####

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
		
		$noClient = $true
		$noServer = $true
		foreach ( $vmData in $allVMData )
		{
			if ( $vmData.RoleName -imatch "client" )
			{
				$clientVMData = $vmData
				$noClient = $false
			}
			elseif ( $vmData.RoleName -imatch "server" )
			{
				$noServer = $fase
				$serverVMData = $vmData
			}
		}
		if ( $noClient )
		{
			Throw "No any master VM defined. Be sure that, Client VM role name matches with the pattern `"*master*`". Aborting Test."
		}
		if ( $noServer )
		{
			Throw "No any slave VM defined. Be sure that, Server machine role names matches with pattern `"*slave*`" Aborting Test."
		}
		#region CONFIGURE VM FOR NET PERF TEST
		LogMsg "CLIENT VM details :"
		LogMsg "  RoleName : $($clientVMData.RoleName)"
		LogMsg "  Public IP : $($clientVMData.PublicIP)"
		LogMsg "  Internal IP : $($clientVMData.InternalIP)"
		LogMsg "  SSH Port : $($clientVMData.SSHPort)"
		LogMsg "SERVER VM details :"
		LogMsg "  RoleName : $($serverVMData.RoleName)"
		LogMsg "  Public IP : $($serverVMData.PublicIP)"
		LogMsg "  Internal IP : $($serverVMData.InternalIP)"
		LogMsg "  SSH Port : $($serverVMData.SSHPort)"

		RemoteCopy -uploadTo $clientVMData.PublicIP -port $serverVMData.SSHPort -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "mkdir -p code" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "mv *.sh code/" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "chmod +x code/*" -runAsSudo

		RemoteCopy -uploadTo $clientVMData.PublicIP -port $clientVMData.SSHPort -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "mkdir -p code" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "mv *.sh code/" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "chmod +x code/*" -runAsSudo

		$KernelVersionVM1 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "uname -a" -runAsSudo
		$KernelVersionVM2 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "uname -a" -runAsSudo

		LogMsg "VM is ready for netperf test"
		LogMsg "VM1 kernel version:- $KernelVersionVM1"
		LogMsg "VM2 kernel version:- $KernelVersionVM2"
		$BufferLengthArray = $($currentTestData.BufferLength)  -split ","
		#Test run number of iteration with given udp buffer lengths
		foreach ($BufferLength in $BufferLengthArray)
		{
			if( $($currentTestData.TestType) -eq "UDP" )
			{
				$UDPtestParams = "UDP  $BufferLength"
				$metaData = "$BufferLength"
			}
			else
			{
				$UDPtestParams = ""
				
			}
			$out = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "bash /home/$user/code/$($currentTestData.testScript) server $user $($serverVMData.InternalIP) " -runAsSudo
			$out = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "bash /home/$user/code/$($currentTestData.testScript) client $user $($serverVMData.InternalIP) $UDPtestParams" -runAsSudo

			$restartvmstatus = RestartAllDeployments -allVMData $allVMData
			if ($restartvmstatus -eq "True")
			{
				$testDuration=0
				LogMsg "VMs Restarted Successfully"
				for($testDuration -le 4100)
				{
					WaitFor -seconds 600
					LogMsg "$UDPtestParams testDuration :- $testDuration "
					$NetStatStatus = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "netstat -natp | grep iperf | grep ESTA | wc -l" -runAsSudo
					LogMsg "$UDPtestParams NetStatStatus :- $NetStatStatus "
					if ($NetStatStatus -eq 0)
					{
						WaitFor -seconds 30
						$NetStatStatus = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "netstat -natp | grep iperf | grep ESTA | wc -l" -runAsSudo
						if ($NetStatStatus -eq 0)
						{
							if($testDuration -lt 3000)
							{
								LogMsg "$UDPtestParams NetStatStatus after 30 sec :- $NetStatStatus "
								LogMsg "$UDPtestParams NetPerf test is ABORTED.."
								$testResult = "ABORTED"
								$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
								break
							}
							else{
								LogMsg "$UDPtestParams NetPerf test is COMPLETED."
								$testResult = "PASS"
								WaitFor -seconds 200
								$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/*.tar" -downloadTo $LogDir -port $serverVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
								$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/*.tar" -downloadTo $LogDir -port $clientVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
								$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/*.csv" -downloadTo $LogDir -port $serverVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
								$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/*.csv" -downloadTo $LogDir -port $clientVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
								$hostname_server = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "hostname"
								$hostname_client = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "hostname"

								$server_summary_file = "$LogDir\summary_file_$hostname_server.csv"
								$client_summary_file = "$LogDir\summary_file_$hostname_client.csv"

								$server_data = Import-Csv $server_summary_file
								$client_data = Import-Csv $client_summary_file
								$UDPresult = @()
								$i = 0
								foreach($item in $server_data)
								{
									$client_throughput = [double]($client_data[$i].AvgThroughput)
									$server_throughput = [double]($server_data[$i].AvgThroughput)
									if($client_throughput)
									{
										$ThroughputDrop = (( $client_throughput - $server_throughput ) * 100)/($client_throughput)
									}else{
										$ThroughputDrop = 0
									}

									$client_packets= [double]($client_data[$i].TotalPackets)
									$server_packets = [double]($server_data[$i].TotalPackets)
									if($client_packets)
									{
										$PacketDrop = (( $client_packets - $server_packets ) * 100)/($client_packets)
									}else{
										$PacketDrop = 0
									}

									$ThroughputDrop = [int]$ThroughputDrop
									$PacketDrop = [int]$PacketDrop
									$Connections = $client_data.GetValue($i).Connections

									$UDPresult +=New-Object PSObject |
									Add-Member -Name Connections -Value $Connections -MemberType NoteProperty -PassThru |
									Add-Member -Name ThroughputDrop -Value $ThroughputDrop -MemberType NoteProperty -PassThru |
									Add-Member -Name PacketDrop -Value $PacketDrop -MemberType NoteProperty -PassThru

									$i++
								}
								$UDPresult
								#$resultArr += $testResult
								$resultSummary +=  CreateResultSummary -testResult $UDPresult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
								break
							}
						}
						else{
							LogMsg "$UDPtestParams NetPerf test is RUNNING.. with $NetStatStatus"
						}
					}
					else{
						LogMsg "$UDPtestParams NetPerf test is RUNNING.. with $NetStatStatus"
					}
					$testDuration=$testDuration+600
				}
			}
			else{
				LogMsg "VMs Restarts Failed.."
				$testResult = "Aborted"
			}
			LogMsg "Test result : $testResult"
		}
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result,$resultSummary
