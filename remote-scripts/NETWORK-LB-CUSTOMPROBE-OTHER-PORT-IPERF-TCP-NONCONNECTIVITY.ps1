Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
    $vm1added = $false
    foreach ($VMdata in $allVMData)
    {
        if ($VMdata.RoleName -imatch $currentTestData.setupType )
        {
            if ( $vm1added )
            {
                $hs1VIP = $VMdata.PublicIP
                $hs1vm2sshport = $VMdata.SSHPort
                $hs1vm2tcpport = $VMdata.TCPtestPort
                $hs1vm2ProbePort = $VMdata.TCPtestProbePort
                $hs1ServiceUrl = $VMdata.URL
            }
            else
            {
                $hs1VIP = $VMdata.PublicIP
                $hs1vm1sshport = $VMdata.SSHPort
                $hs1vm1tcpport = $VMdata.TCPtestPort
                $hs1vm1ProbePort = $VMdata.TCPtestProbePort
                $hs1ServiceUrl = $VMdata.URL
                $vm1added = $true
            }
        }
        elseif ($VMdata.RoleName -imatch "DTAP")
        {
            $dtapServerIp = $VMdata.PublicIP
            $dtapServerSshport = $VMdata.SSHPort
            $dtapServerTcpport = $VMdata.TCPtestPort
        }
    }	
	LogMsg "Test Machine 1 : $hs1VIP : $hs1vm1sshport"
	LogMsg "Test Machine 2 : $hs1VIP : $hs1vm2sshport"
	LogMsg "DTAP Machine : $dtapServerIp : $hs1vm1sshport"
	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds
	
	$testPort = $hs1vm1tcpport + 10
	$pSize = 6
	$cmd1="python start-server.py -p $testPort && mv Runtime.log start-server.py.log -f"
	$cmd2="python start-server.py -p $testPort && mv Runtime.log start-server.py.log -f"
	$cmd3="python start-client.py -c $hs1VIP -p $testPort -t10 -P$pSize"
	$cmd11="python start-server-without-stopping.py -p $hs1vm1ProbePort -log iperf-probe.txt"
	$cmd22="python start-server-without-stopping.py -p $hs1vm2ProbePort -log iperf-probe.txt"
		
	$server1 = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodeDip $hs1vm1.IpAddress
	$server2 = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -nodeTcpPort $hs1vm2tcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodeDip $hs1vm2.IpAddress
	$client = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd3 -user $user -password $password -files $currentTestData.files -logDir $LogDir

	foreach ($mode in $currentTestData.TestMode.Split(",")) 
	{
		mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
		try
		{
			$testResult = $null
			if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
			{
				$client.cmd = "python start-client.py -c $hs1VIP -p $testPort -t$iperfTimeoutSeconds -P$pSize"
			}

			if(($mode -eq "URL") -or ($mode -eq "Hostname"))
			{
				$client.cmd = "python start-client.py -c $hs1ServiceUrl -p $testPort -t$iperfTimeoutSeconds -P$pSize"
			}
			mkdir $LogDir\$mode\Server1 -ErrorAction SilentlyContinue | out-null
			mkdir $LogDir\$mode\Server2 -ErrorAction SilentlyContinue | out-null
			$server1.logDir = $LogDir + "\$mode\Server1"
			$server2.logDir = $LogDir + "\$mode\Server2"
			$client.logDir = $LogDir + "\$mode"
			RemoteCopy -uploadTo $server1.ip -port $server1.sshPort -files $server1.files -username $server1.user -password $server1.password -upload
			RemoteCopy -uploadTo $server2.Ip -port $server2.sshPort -files $server2.files -username $server2.user -password $server2.password -upload
			RemoteCopy -uploadTo $client.Ip -port $client.sshPort -files $client.files -username $client.user -password $client.password -upload

			$suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "chmod +x *" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshPort -command "chmod +x *" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "chmod +x *" -runAsSudo

			$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshport -command "echo Test Started > iperf-server.txt" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "echo Test Started > iperf-server.txt" -runAsSudo
			$server1.cmd = $cmd1
			$server2.cmd = $cmd2			
			StartIperfServer $server1
			StartIperfServer $server2

			#$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshport -command "python start-server-without-stopping.py -p $hs1vm1ProbePort -log iperf-probe.txt" -runAsSudo
			#$suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "python start-server-without-stopping.py -p $hs1vm2ProbePort -log iperf-probe.txt" -runAsSudo
			$server1.cmd = $cmd11
			$server2.cmd = $cmd22
			StartIperfServer $server1
			StartIperfServer $server2
			
			$isServerStarted = IsIperfServerStarted $server1
			$isServerStarted = IsIperfServerStarted $server2
			WaitFor -seconds 30
			if(($isServerStarted -eq $true) -and ($isServerStarted -eq $true))
			{
				LogMsg "Iperf Server1 and Server2 started successfully. Listening TCP port $($client.tcpPort) ..."
#>>>On confirmation, of server starting, let's start iperf client...
				$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshport -command "echo Test Started > iperf-client.txt" -runAsSudo
				StartIperfClient $client
				$isClientStarted = IsIperfClientStarted $client
				$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshport -command "echo TestComplete >> iperf-server.txt" -runAsSudo
				$suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "echo TestComplete >> iperf-server.txt" -runAsSudo
				if($isClientStarted -eq $false)
				{
					$server1State = IsIperfServerRunning $server1
					$server2State = IsIperfServerRunning $server2
					if(($server1State -eq $false) -and ($server2State -eq $false))
					{
						LogMsg "Test Finished..!"
						$testResult = "PASS"
					} 
					else
					{
						if ( $server1State -eq $true)
						{
							LogErr "Connections observed on server1. Test Finished..!"
							$testResult = "FAIL"
						}
						if ( $server2State -eq $true)
						{
							LogErr "Connections observed on server2. Test Finished..!"
							$testResult = "FAIL"
						}
					}
				} 
				else 
				{
					$testResult = "FAIL"
#LogMsg "Failured detected in client connection."
					LogErr "Ohh, client connected.. Verifying that it connected to server.."
					$server1State = IsIperfServerRunning $server1
					$server2State = IsIperfServerRunning $server2
					if(($server1State -eq $false))
					{
						LogMsg "Not Connected to server1. Please check the logs.. where the client was connected."
					}
					else
					{
						LogMsg "Connections observed on server1. Test Finished..!"
					}
					if(($server2State -eq $false))
					{
						LogMsg "Not Connected to server2. Please check the logs.. where the client was connected."
					}
					else
					{
						LogMsg "Connections observed on server2. Test Finished..!"
					}
					LogMsg "Test Finished..!"
				}
			} 
			else
			{
				LogErr "Unable to start iperf-server. Aborting test."
				RemoteCopy -download -downloadFrom $server1.ip -files "/home/$user/iperf-server.txt" -downloadTo $server1.LogDir -port $server1.sshPort -username $server1.user -password $server1.password
				RemoteCopy -download -downloadFrom $server2.ip -files "/home/$user/iperf-server.txt" -downloadTo $server2.LogDir -port $server2.sshPort -username $server2.user -password $server2.password
				$testResult = "Aborted"
			}
			LogMsg "$($currentTestData.testName) : $mode : $testResult"
		}
		catch
		{
			$ErrorMessage =  $_.Exception.Message
			LogErr "EXCEPTION : $ErrorMessage"   
		}
		Finally
		{
			$metaData = "$Value : $mode" 
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
