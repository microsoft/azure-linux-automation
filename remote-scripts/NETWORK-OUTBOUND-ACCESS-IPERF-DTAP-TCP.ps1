Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
        #Extract VM data...
        $DeployedVMs = GetAllDeployementData -DeployedServices $isDeployed -ResourceGroups $isDeployed
        foreach ($VMdata in $DeployedVMs)
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

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RemoteCopy -uploadTo $dtapServerIp -port $dtapServerSshport -files $currentTestData.files -username $user -password $password -upload
		$suppressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x * && rm -rf *.log *.txt" -runAsSudo
		$suppressedOut = RunLinuxCmd -username $user -password $password -ip $dtapServerIp -port $dtapServerSshport -command "chmod +x * && rm -rf *.log *.txt" -runAsSudo

		$cmd1="python start-server.py -p $dtapServerTcpport && mv Runtime.log start-server.py.log -f"
		$cmd2="python start-client.py -c $dtapServerIp -p $dtapServerTcpport -t$iperfTimeoutSeconds"
		$server = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
		$client = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir
		$testresult=IperfClientServerTest -server $server -client $client
		LogMsg "$($currentTestData.testName) : $testResult"
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"
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
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result