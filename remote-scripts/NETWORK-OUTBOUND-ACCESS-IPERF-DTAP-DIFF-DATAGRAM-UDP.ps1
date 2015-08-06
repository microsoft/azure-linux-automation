Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",")
$testResult = ""
$resultArr = @()
$result = ""
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
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
	$cmd1="python start-server.py -p $dtapServerUdpport -u yes && mv Runtime.log start-server.py.log -f"
	$cmd2="python start-client.py -c $dtapServerIp -p $dtapServerUdpport -t$iperfTimeoutSeconds -u yes -l"

	$server = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	$client = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir

	foreach ($Value in $SubtestValues) 
	{
		try
		{
			$testResult = $null
			$client.cmd = "python start-client.py -c $dtapServerIp -p $dtapServerUdpport -t10 -u yes -l $Value"
			LogMsg "Test Started for UDP Datagram size $Value"
			mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
			$server.logDir = $LogDir + "\$Value"
			$client.logDir = $LogDir + "\$Value"
			$testResult = IperfClientServerUDPDatagramTest $server $client
			LogMsg "$($currentTestData.testName) : $Value : $testResult"
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
