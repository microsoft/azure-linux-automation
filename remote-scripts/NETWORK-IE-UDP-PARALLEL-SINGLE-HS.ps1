<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",")
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
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

	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds
	$cmd1="python start-server.py -i1 -p $hs1vm1udpport -u yes && mv Runtime.log start-server.py.log -f"
	$cmd2="python start-client.py -c $($hs1vm1.IpAddress) -i1 -p $hs1vm1udpport -t$iperfTimeoutSeconds  -P 1 -u yes"

	$server = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeUdpPort $hs1vm1udpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	$client = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -nodeudpPort $hs1vm2udpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir

	foreach ($Value in $SubtestValues) 
	{
		#Create New directory for each subtest value..
		mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null

		#perform test for each test mode..
		foreach ($mode in $currentTestData.TestMode.Split(","))
		{	  
			try
			{
				$testResult = $null
				LogMsg "Starting test with $value parallel connections in $mode mode.."

				if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
				{
					$client.cmd = "python start-client.py -c $hs1vm1IP  -p $hs1vm1udpport -t$iperfTimeoutSeconds  -P$Value -u yes"
				}

				if(($mode -eq "URL") -or ($mode -eq "Hostname"))
				{
					$client.cmd = "python start-client.py -c $hs1vm1Hostname  -p $hs1vm1udpport -t$iperfTimeoutSeconds -P$Value -u yes"
				}

				#Create Directory for each test mode to collect all results..
				mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null

				$server.logDir = $LogDir + "\$Value\$mode"
				$client.logDir = $LogDir + "\$Value\$mode"
				
				$testResult=IperfClientServerUDPTestParallel $server $client
				LogMsg "$($currentTestData.testName) : $Value : $mode : $testResult"
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