Import-Module .\TestLibs\RDFELibs.psm1 -Force
$resultArr = @()
$testResult = ""
$result = ""
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
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


	$cmd1="python start-server.py -p $hs1vm1udpport -u yes && mv Runtime.log start-server.py.log -f"
	$server = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1udpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	
	foreach ($mode in $currentTestData.TestMode.Split(","))
	{ 
		try
		{
			$testResult = $null
			RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
			RemoteCopy -uploadTo $hs1VIP -port $hs1vm2sshport -files $currentTestData.files -username $user -password $password -upload
			$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x * && rm -rf *.txt *.log" -runAsSudo
			$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "chmod +x * && rm -rf *.txt *.log" -runAsSudo
			$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds
			
			#>>>Start server...
			LogMsg "Starting the test in $mode mode.."
			mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
			LogMsg "Starting iperf Server..."
			$suppressedOut = StartIperfServer -node $server
			#$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python start-server.py -i1 -p $hs1vm1udpport -u yes && mv Runtime.log start-server.py.log -f" -runAsSudo
			#RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/start-server.py.log" -downloadTo $LogDir\$mode  -port $hs1vm1sshport -username $user -password $password
			
			#>>>Verify, if server started...
			LogMsg "Verifying if server is started or not.."
			#RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/isServerStarted.txt" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
			#$isServerStarted = Get-Content $LogDir\isServerStarted.txt

			if(IsIperfServerStarted -node $server)
			{
				LogMsg "iperf Server started successfully. Listening UDP port $hs1vm1UDPport..."

				#>>>On confirmation, of server starting, let's start iperf client...
				LogMsg "Startin iperf client and trying to connect to port $hs1vm1udpport..."
				if(($mode -eq "IP") -or ($mode -eq "VIP"))
				{
					$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "python start-client.py -c $hs1vm1IP -i1 -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes " -runAsSudo
				}
				if(($mode -eq "URL") -or ($mode -eq "Hostname"))
				{
					$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "python start-client.py -c $hs1vm1Hostname -i1 -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes " -runAsSudo
				}
				$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "mv Runtime.log start-client.py.log -f" -runAsSudo
				RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/start-client.py.log, /home/$user/iperf-client.txt" -downloadTo $LogDir\$mode  -port $hs1vm2sshport -username $user -password $password

				#>>>Verify client...
				RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/state.txt, /home/$user/Summary.log" -downloadTo $LogDir -port $hs1vm2sshport -username $user -password $password
				$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "rm -rf /home/$user/state.txt /home/$user/Summary.log" -runAsSudo
				$clientState = Get-Content $LogDir\state.txt
				$clientSummary = Get-Content $LogDir\Summary.log

				#>>>Remove Temporary files..
				Remove-Item $LogDir\state.txt -Force
				Remove-Item $LogDir\Summary.log -Force

				if($clientState -eq "TestCompleted" -and $clientSummary -eq "PASS")
				{
					#>>>Now we know that our client was connected. Let's go and check the server now...
					$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python check-server.py && mv Runtime.log check-server.py.log -f" -runAsSudo
					RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/check-server.py.log, /home/$user/iperf-server.txt" -downloadTo $LogDir\$mode  -port $hs1vm1sshport -username $user -password $password
					RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/state.txt, /home/$user/Summary.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
					$serverState = Get-Content $LogDir\state.txt
					$serverSummary =  Get-Content $LogDir\Summary.log

					#>>>Remove Temporary files..
					Remove-Item $LogDir\state.txt -Force
					Remove-Item $LogDir\Summary.log -Force
					
					#>>>Verify client connections appeared on server...
					if($serverState -eq "TestCompleted" -and $serverSummary -eq "PASS")
					{
						LogMsg "Test Finished..!"
						$testResult = "PASS"
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
