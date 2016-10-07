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
		$hs1VIP = $allVMData[0].PublicIP
		$hs1ServiceUrl = $allVMData[0].URL
		$hs1vm1IP = $allVMData[0].InternalIP
		$hs1vm1Hostname = $allVMData[0].RoleName
		$hs1vm1sshport = $allVMData[0].SSHPort
		$hs1vm1tcpport = $allVMData[0].TCPtestPort
		$hs1vm1udpport = $allVMData[0].UDPtestPort

		$hs1vm2IP = $allVMData[1].InternalIP
		$hs1vm2Hostname = $allVMData[1].RoleName
		$hs1vm2sshport = $allVMData[1].SSHPort
		$hs1vm2tcpport = $allVMData[1].TCPtestPort
		$hs1vm2udpport = $allVMData[1].UDPtestPort

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mkdir code" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv *.sh code/" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x code/*" -runAsSudo

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm2sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "mkdir code" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "mv *.sh code/" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "chmod +x code/*" -runAsSudo

		$KernelVersionVM1 = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo
		$KernelVersionVM2 = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "uname -a" -runAsSudo

		LogMsg "VM is ready for netperf test"
		LogMsg "VM1 kernel version:- $KernelVersionVM1"
		LogMsg "VM2 kernel version:- $KernelVersionVM2"
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash /home/$user/code/$($currentTestData.testScript) server $user $hs1vm1IP " -runAsSudo
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "bash /home/$user/code/$($currentTestData.testScript) client $user $hs1vm1IP $($currentTestData.TestType) $password" -runAsSudo

		$restartvmstatus = RestartAllDeployments -allVMData $allVMData
		if ($restartvmstatus -eq "True")
		{
			$testDuration=0
			LogMsg "VMs Restarted Successfully"
			for($testDuration -le 4100)
			{
				WaitFor -seconds 600
				LogMsg "testDuration :- $testDuration "
				$NetStatStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "netstat -natp | grep iperf | grep ESTA | wc -l" -runAsSudo
				LogMsg "NetStatStatus :- $NetStatStatus "
				if ($NetStatStatus -eq 0)
				{
					WaitFor -seconds 30
					$NetStatStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "netstat -natp | grep iperf | grep ESTA | wc -l" -runAsSudo
					if ($NetStatStatus -eq 0)
					{
						if($testDuration -lt 3300)
						{
							LogMsg "NetStatStatus after 30 sec :- $NetStatStatus "
							LogMsg "NetPerf test is ABORTED.."
							$testResult = "ABORTED"
							break
						}
						else{
							LogMsg "NetPerf test is COMPLETED."
							$testResult = "PASS"
							WaitFor -seconds 200
							$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/*.tar" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
							$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/*.tar" -downloadTo $LogDir -port $hs1vm2sshport -username $user -password $password 2>&1 | Out-Null
							$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/*.csv" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
							$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/*.csv" -downloadTo $LogDir -port $hs1vm2sshport -username $user -password $password 2>&1 | Out-Null
							$hostname_server = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "hostname"
							$hostname_client = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "hostname"

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

							break
						}
					}
					else{
						LogMsg "NetPerf test is RUNNING.. with $NetStatStatus"
					}
				}
				else{
					LogMsg "NetPerf test is RUNNING.. with $NetStatStatus"
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
