Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
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

	$pingFrom = CreatePingNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -files $currentTestData.files -logDir $LogDir 
	LogMsg "ping will be done from $hs1VIP"
	foreach ($mode in $currentTestData.TestMode.Split(","))
	{ 
		try
		{
			$testResult = $null
			if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
			{
				$pingFrom.cmd = "$python_cmd ping.py -x $hs2VIP -c 10"
			}
			if(($mode -eq "URL") -or ($mode -eq "Hostname"))
			{
				$pingFrom.cmd = "$python_cmd ping.py -x $hs2ServiceUrl -c 10"
			}
			LogMsg "Test Started in $mode mode.."

			mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
			$pingFrom.logDir = $LogDir + "\$mode"
			$pingResult = DoPingTest -pingFrom $pingFrom
			if($pingResult -eq "PASS")
			{
				$testResult = "FAIL"
			}
			else
			{
				$testResult = "PASS"
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
return $result , $resultSummary