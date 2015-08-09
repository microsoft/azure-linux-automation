Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
    foreach ($VMdata in $allVMData)
    {
        if ($VMdata.RoleName -imatch "PublicEndpoint")
        {
            $hs1VIP = $VMdata.PublicIP
            $hs1vm1sshport = $VMdata.SSHPort
            $hs1vm1tcpport = $VMdata.TCPtestPort
            $hs1vm1udpport = $VMdata.UDPtestPort
            $hs1ServiceUrl = $VMdata.URL
        }
        elseif ($VMdata.RoleName -imatch "DTAP")
        {
            $dtapServerIp = $VMdata.PublicIP
            $dtapServerSshport = $VMdata.SSHPort
            $dtapServerTcpport = $VMdata.TCPtestPort
            $dtapServerUdpport = $VMdata.UDPtestPort
        }
    }
	LogMsg "Test Machine : $hs1VIP : $hs1vm1sshport"
	LogMsg "DTAP Machine : $dtapServerIp : $hs1vm1sshport"
	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds

	$server = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport  -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	$client = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport  -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir

	foreach ($mode in $currentTestData.TestMode.Split(","))
	{
		try
		{
			$testResult = $null
			mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
			$server.cmd ="python start-server.py -p $hs1vm1udpport -u yes && mv Runtime.log start-server.py.log -f"
			if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
			{
				$client.cmd ="python start-client.py -c $hs1VIP -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes -l1420"
			}
			if(($mode -eq "URL") -or ($mode -eq "Hostname"))
			{
				$client.cmd ="python start-client.py -c $hs1ServiceUrl -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes -l1420"
			}
			$server.logDir = "$LogDir\$mode"
			$client.logDir = "$LogDir\$mode"

			RemoteCopy -uploadTo $server.ip -port $server.sshPort -files $server.files -username $server.user -password $server.password -upload
			RemoteCopy -uploadTo $client.Ip -port $client.sshPort -files $client.files -username $client.user -password $client.password -upload

			$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "chmod +x *.py && rm -rf *.txt *.log" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "chmod +x *.py && rm -rf *.txt *.log" -runAsSudo

			$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo TestStarted > iperf-client.txt" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "echo TestStarted > iperf-server.txt" -runAsSudo

			$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo ClientStarted1 >> iperf-client.txt" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "echo ServerStarted1 >> iperf-server.txt" -runAsSudo
			StartIperfServer $server
			$isServerStarted = IsIperfServerStarted $server 
			if($isServerStarted -eq $true)
			{
				LogMsg "iperf Server started successfully. Listening TCP port $($client.tcpPort) ..."
				
				#>>>On confirmation, of server starting, let's start iperf client...
				StartIperfClient $client
				$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo ClientStopped1 >> iperf-client.txt" -runAsSudo
				$isClientStarted = IsIperfClientStarted $client -beginningText ClientStarted1 -endText ClientStopped1

				if($isClientStarted -eq $true)
				{
					$serverState = IsIperfServerRunning $server
				 
					if($serverState -eq $true)
					{
						LogMsg "Stopping Server.."
						$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "python stop-server.py" -runAsSudo
						$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "echo ServerStopped1 >> iperf-server.txt" -runAsSudo
						LogMsg "Stopping Client.."
						$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "python stop-client.py" -runAsSudo
						

						#Step 2. Do not start iperf server and start the client..
						LogMsg "Starting the client without starting the server.."
						$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo ClientStarted2 >> iperf-client.txt" -runAsSudo

						StartIperfClient $client
						$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "python stop-client.py" -runAsSudo
						$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo ClientStopped2 >> iperf-client.txt" -runAsSudo
						$isClientStarted = IsIperfClientStarted $client -beginningText ClientStarted2 -endText ClientStopped2
						Write-Host "isClientConnecte : $isClientStarted"
						if($isClientStarted -eq $true)
						{
							LogMsg "Becasue of UDP test, client shows that it is connected to server even thought not connected."
							LogMsg "Starting the Server again.."
							$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "echo ServerStarted3 >> iperf-server.txt" -runAsSudo
							StartIperfServer $server
							$isServerStarted = IsIperfServerStarted $server
							if($isServerStarted -eq $true)
							{
								LogMsg "iperf Server started successfully. Listening TCP port $($client.tcpPort) ..."
								
								#On confirmation, of server starting, let's start iperf client...
								$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo ClientStarted3 >> iperf-client.txt" -runAsSudo
								StartIperfClient $client
								$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo ClientStopped3 >> iperf-client.txt" -runAsSudo
								$isClientStarted = IsIperfClientStarted $client -beginningText ClientStarted3 -endText ClientStopped3
								if($isClientStarted -eq $true)
								{
									$serverState = IsIperfServerRunning $server
									$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "python stop-server.py" -runAsSudo
									$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "echo ServerStopped3 >> iperf-server.txt" -runAsSudo

									if($serverState -eq $true)
									{
										LogMsg "Server was successfully connected to client.."
										$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "echo TestCompleted >> iperf-client.txt" -runAsSudo
										$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshPort -command "echo TestCompleted >> iperf-server.txt" -runAsSudo
										$testResult = "PASS"
									}
									else
									{
										LogMsg "Failures Detected in on Server."
										$testResult = "FAIL"
									}
								}
								else
								{
									LogMsg "Client failed to connect.."
									$testResult = "FAIL"
								}
							}
							else
							{
								LogMsg "Server Failed to start."
								$testResult = "FAIL"
							}

						}
						else
						{
							LogMsg "Client connected to server without starting the server."
							$testResult = "FAIL"
						}
					}
					else
					{
						LogMsg "Test Finished..!"
						$testResult = "FAIL"
					}
				}
				else
				{
					LogMsg "Failured detected in client connection."
					LogMsg "Test Finished..!"
					$testResult = "FAIL"
				}
			}
			else
			{
				LogMsg "Unable to start iperf-server. Aborting test."
				$testResult = "Aborted"
			}
			LogMsg "$($currentTestData.testName) : $mode : $testResult"
		}
		catch
		{
			$ErrorMessage =  $_.Exception.Message
			LogMsg "EXCEPTION : $ErrorMessage"   
		}
		Finally
		{
			$metaData = $mode 
			if (!$testResult)
			{
				$testResult = "Aborted"
			}
			$resultArr += $testResult
			$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
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