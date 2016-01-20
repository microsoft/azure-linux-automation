<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
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

	$hs2VIP = $allVMData[1].PublicIP
	$hs2ServiceUrl = $allVMData[1].URL
	$hs2vm1IP = $allVMData[1].InternalIP
	$hs2vm1Hostname = $allVMData[1].RoleName
	$hs2vm1sshport = $allVMData[1].SSHPort
	$hs2vm1tcpport = $allVMData[1].TCPtestPort
	$hs2vm1udpport = $allVMData[1].UDPtestPort

	$testPort = $hs1vm1tcpport + 10
	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds

	foreach ($mode in $currentTestData.TestMode.Split(","))
	{
		try
		{
			LogMsg "Starting the test in $mode.."
			$cmd1="$python_cmd start-server.py -p $testPort   && mv Runtime.log start-server.py.log"
		
			if(($mode -eq "IP") -or ($mode -eq "VIP"))
			{
				$cmd2="$python_cmd start-client.py -c $hs1vm1IP -p $testPort  -t$iperfTimeoutSeconds"
			}
			if(($mode -eq "URL") -or ($mode -eq "Hostname"))
			{
				$cmd2="$python_cmd start-client.py -c $hs1vm1Hostname -p $testPort  -t$iperfTimeoutSeconds"
			}

			$server = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodetcpPort $testPort
			LogMsg "$hs1VIP set as iperf server"
			$client = CreateIperfNode -nodeIp $hs2VIP -nodeSshPort $hs2vm1sshport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodetcpPort $testPort
			mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
			$server.logDir = $LogDir + "\$mode"
			$client.logDir = $LogDir + "\$mode"
			$testResult = IperfClientServerTCPNonConnectivity -server $server -client $client
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