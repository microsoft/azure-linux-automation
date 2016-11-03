# This script deploys the VMs for the network performance test and trigger test.
# Author: Sivakanth Rebba
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
		$allVMData  = GetAllDeployementData -DeployedServices $isDeployed
		Set-Variable -Name AllVMData -Value $allVMData
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

		$KernelVersionVM1 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "uname -r" -runAsSudo
		$KernelVersionVM2 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "uname -r" -runAsSudo
		LogMsg "VM1 kernel version:- $KernelVersionVM1"
		LogMsg "VM2 kernel version:- $KernelVersionVM2"
		 
		if($Distro -imatch "UBUNTU")
		{
			$packages = 'wget dos2unix tar at bc gcc git iperf psmisc  fio bind9 xfsprogs libaio1 mdadm lvm2 sysstat sshpass iperf3 python-argparse python-paramiko  sysbench iozone3'
			$packInstall = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "apt-get -y update" -runAsSudo -runmaxallowedtime 900
			$packInstall = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "apt-get -y install $packages" -runAsSudo -runmaxallowedtime 900
			$packInstall1 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "apt-get -y update " -runAsSudo -runmaxallowedtime 900
			$packInstall1 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "apt-get -y install $packages" -runAsSudo -runmaxallowedtime 900
		}
		
		LogMsg "VM is ready for netperf test"
		#Test run number of iteration with given udp buffer lengths
		$BufferLengthArray = $($currentTestData.BufferLength) -split ","
		foreach ($BufferLength in $BufferLengthArray)
		{
			if( $($currentTestData.TestType) -eq "UDP" )
			{
				$UDPtestParams = "UDP $BufferLength"
				$metaData = "$($currentTestData.TestType) $BufferLength"
			}
			else
			{
				$UDPtestParams = "TCP Default"
				$metaData = "$($currentTestData.TestType) Default"
				
			}
			$out = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "bash /home/$user/code/$($currentTestData.testScript) server $user $($serverVMData.InternalIP) $UDPtestParams" -runAsSudo
			$out = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "bash /home/$user/code/$($currentTestData.testScript) client $user $($serverVMData.InternalIP) $UDPtestParams" -runAsSudo

			$restartvmstatus = RestartAllDeployments -allVMData $allVMData
			if ($restartvmstatus -eq "True")
			{
				$testDuration=0
				LogMsg "VMs Restarted Successfully"
				$KernelVersionVM1 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "uname -r" -runAsSudo
				$KernelVersionVM2 = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "uname -r" -runAsSudo
				LogMsg "VM1 kernel version:- $KernelVersionVM1"
				LogMsg "VM2 kernel version:- $KernelVersionVM2"

				LogMsg "$UDPtestParams testDuration :- $testDuration .. waiting 300s for client connections"
				WaitFor -seconds 300
				while($testDuration -le 4100)
				{
					
					LogMsg "$UDPtestParams testDuration :- $testDuration "
					$testStatus = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "cat /home/$user/code/state.txt" -runAsSudo
					LogMsg "$UDPtestParams testStatus :- $testStatus "
					if ($testStatus -eq "TestRunning")
					{
						$infoDuration = 0
						while($infoDuration -le 600)
						{
							$testStatusInfo = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "tail -1 /home/$user/code/client.log" -runAsSudo
							if($testStatusInfo -imatch "Updating test case state to completed")
							{
								LogMsg "$UDPtestParams $testDuration-testStatusInfo-$infoDuration :- COMPLETED"
								break
							}
							else
							{
								LogMsg "$UDPtestParams $testDuration-testStatusInfo-$infoDuration :- $testStatusInfo "
								WaitFor -seconds 60
							}
							$infoDuration=$infoDuration+60
						}
					}
					elseif($testStatus -eq "TestCompleted")
					{
						LogMsg "$UDPtestParams NetPerf test is COMPLETED."
						$testResult = "PASS"
						WaitFor -seconds 200
						$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/logs-$($clientVMData.RoleName)-UDP-$($BufferLength)/*.csv" -downloadTo $LogDir -port $clientVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
						$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/*.tar.gz, /home/$user/code/*.log, /home/$user/code/*.txt" -downloadTo $LogDir -port $clientVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
						$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/*.tar.gz, /home/$user/code/*.log" -downloadTo $LogDir -port $serverVMData.SSHPort -username $user -password $password 2>&1 | Out-Null
						$out = RemoteCopy -download -downloadFrom $clientVMData.PublicIP -files "/home/$user/code/logs-$($serverVMData.RoleName)-UDP-$($BufferLength)/*.csv" -downloadTo $LogDir -port $serverVMData.SSHPort -username $user -password $password 2>&1 | Out-Null						
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "UDP $BufferLength" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						break
					}
					elseif($testStatus -eq "TestFailed")
					{
						LogMsg "$UDPtestParams NetPerf test is FAILED.."
						$testResult = "FAIL"
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "UDP $BufferLength" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						break
					}
					else
					{
						LogMsg "$UDPtestParams NetPerf test is ABORTED.."
						$testResult = "ABORTED"
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "UDP $BufferLength" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						break
					}
					$testDuration=$testDuration+600
				}
				LogMsg "Resetting the /etc/rc.local"
				$out = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $serverVMData.SSHPort -command "sed -i '/$user / d' /etc/rc.local" -runAsSudo
				$out = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "sed -i '/$user / d' /etc/rc.local" -runAsSudo
			}
			else{
				LogMsg "VMs Restarts Failed.."
				$testResult = "Aborted"
			}
			LogMsg "Test result : $testResult"
		}
		if ($testResult -imatch "PASS")
		{
			foreach ($BufferLength in $BufferLengthArray)
			{
				try
				{
					LogMsg "UDP $BufferLength results parsing STARTED.."
					$server_summary_file = "$LogDir\summary_file_$($serverVMData.RoleName)_UDP_$($BufferLength).csv"
					$client_summary_file = "$LogDir\summary_file_$($clientVMData.RoleName)_UDP_$($BufferLength).csv"

					$server_data = Import-Csv $server_summary_file
					$client_data = Import-Csv $client_summary_file
					$UDPresult = @()
					$i = 0
					foreach($item in $server_data)
					{
						$client_throughput = [double]($client_data[$i].'Avg Throughput')
						$server_throughput = [double]($server_data[$i].'Avg Throughput')
						if($client_throughput)
						{
							$ThroughputDrop = (( $client_throughput - $server_throughput ) * 100)/($client_throughput)
						}else{
							$ThroughputDrop = 0
						}

						$client_packets= [double]($client_data[$i].'Total packets')
						$server_packets = [double]($server_data[$i].'Total packets')
						if($client_packets)
						{
							$PacketDrop = (( $client_packets - $server_packets ) * 100)/($client_packets)
						}else{
							$PacketDrop = 0
						}
						
						$ThroughputDrop = [math]::abs([math]::Round($ThroughputDrop,2))
						$PacketDrop = [math]::abs([math]::Round($PacketDrop,2))
						$Connections = $client_data.GetValue($i).Connections
						$TxThroughput_Gbps = $client_data.GetValue($i).'Avg Throughput'
						$RxThroughput_Gbps = $server_data.GetValue($i).'Avg Throughput'
						
						$UDPresult +=New-Object PSObject |
						Add-Member -Name Connections -Value $Connections -MemberType NoteProperty -PassThru |
						Add-Member -Name TxThroughput_Gbps -Value $TxThroughput_Gbps -MemberType NoteProperty -PassThru |
						Add-Member -Name RxThroughput_Gbps -Value $RxThroughput_Gbps -MemberType NoteProperty -PassThru |
						Add-Member -Name ThroughputDrop -Value $ThroughputDrop -MemberType NoteProperty -PassThru |
						Add-Member -Name DatagramLoss -Value $PacketDrop -MemberType NoteProperty -PassThru

						$i++
					}
					$UDPresult
					LogMsg "UDP $BufferLength results parsing DONE!!"
					Write-Output $UDPresult | Format-Table
					#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "UDP $BufferLength" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
					
					LogMsg "Uploading the test results to DB STARTED.."
					$dataSource = $xmlConfig.config.Azure.database.server
					$dbuser = $xmlConfig.config.Azure.database.user
					$dbpassword = $xmlConfig.config.Azure.database.password
					$database = $xmlConfig.config.Azure.database.dbname
					$dataTableName = $xmlConfig.config.Azure.database.dbtable
					$TestCaseName = $xmlConfig.config.Azure.database.testTag
					if ($dataSource -And $dbuser -And $dbpassword -And $database -And $dataTableName) 
					{
						$GuestDistro	= cat "$LogDir\VM_properties.csv" | Select-String "OS type"| %{$_ -replace ",OS type,",""}						
						if ( $UseAzureResourceManager )
						{
							$HostType	= "Azure-ARM"
						}
						else
						{
							$HostType	= "Azure"
						}
						$HostBy	= ($xmlConfig.config.Azure.General.Location).Replace('"','')
						$HostOS	= cat "$LogDir\VM_properties.csv" | Select-String "Host Version"| %{$_ -replace ",Host Version,",""}
						$GuestOSType	= "Linux"
						$GuestDistro	= cat "$LogDir\VM_properties.csv" | Select-String "OS type"| %{$_ -replace ",OS type,",""}
						$GuestSize = $clientVMData.InstanceSize
						$KernelVersion	= cat "$LogDir\VM_properties.csv" | Select-String "Kernel version"| %{$_ -replace ",Kernel version,",""}
						$IPVersion = "IPv4"
						$ProtocolType = $($currentTestData.TestType)

						$connectionString = "Server=$dataSource;uid=$dbuser; pwd=$dbpassword;Database=$database;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
						$SQLQuery = "INSERT INTO $dataTableName (TestCaseName,TestDate,HostType,HostBy,HostOS,GuestOSType,GuestDistro,GuestSize,KernelVersion,IPVersion,ProtocolType,SendBufSize_KBytes,NumberOfConnections,TxThroughput_Gbps,RxThroughput_Gbps,DatagramLoss) VALUES "

						for($i = 0; $i -lt $($UDPresult.Count); $i++)
						{
							$SQLQuery += "('$TestCaseName','$(Get-Date -Format yyyy-MM-dd)','$HostType','$HostBy','$HostOS','$GuestOSType','$GuestDistro','$GuestSize','$KernelVersion','$IPVersion','$ProtocolType','$($BufferLength[0])','$($UDPresult[$i].Connections)','$($UDPresult[$i].TxThroughput_Gbps)','$($UDPresult[$i].RxThroughput_Gbps)','$($UDPresult[$i].DatagramLoss)'),"
						}
						$SQLQuery = $SQLQuery.TrimEnd(',')
						LogMsg $SQLQuery
						$connection = New-Object System.Data.SqlClient.SqlConnection
						$connection.ConnectionString = $connectionString
						$connection.Open()

						$command = $connection.CreateCommand()
						$command.CommandText = $SQLQuery
						$result = $command.executenonquery()
						$connection.Close()
						LogMsg "Uploading the test results to DB DONE!!"
					}
					else
					{
						LogMsg "Invalid database details. Failed to upload result to database!"
						$testResult = "FAIL"
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "UDP $BufferLength UPLOAD RESULTS TO DB" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
					}
				}
				catch
				{
					$ErrorMessage =  $_.Exception.Message
					LogMsg "EXCEPTION : $ErrorMessage"
					$testResult = "ABORTED"
				}
				Finally
				{
					$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "UDP $BufferLength UPLOAD RESULTS TO DB" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				}
			}
		}
		else
		{
			LogMsg "Skipping upload results to database!"
			$testResult = "ABORTED"
			$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"
		$testResult = "ABORTED"
		$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
	}
	Finally
	{
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
	}
}
else
{
	$metaData = ""
	$testResult = "Aborted"
	$resultArr += $testResult
	$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result,$resultSummary
