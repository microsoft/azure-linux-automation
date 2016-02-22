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
	
	$hs1vm2IP = $allVMData[1].InternalIP
	$hs1vm2Hostname = $allVMData[1].RoleName
	$hs1vm2sshport = $allVMData[1].SSHPort
	$hs1vm2tcpport = $allVMData[1].TCPtestPort
	$hs1vm2udpport = $allVMData[1].UDPtestPort

	$pingFrom = CreatePingNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -files $currentTestData.files -logDir $LogDir 
	foreach ($mode in $currentTestData.TestMode.Split(","))
	{ 
		try
		{
			$testResult = $null
			if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
			{
				$pingFrom.cmd = "$python_cmd ping.py -x $hs1vm2IP -c 10"
			}

			if(($mode -eq "URL") -or ($mode -eq "Hostname"))
			{
				$pingFrom.cmd = "$python_cmd ping.py -x  $hs1vm2Hostname  -c 10"
			}
			LogMsg "Test Started in $mode mode.."

			mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
			$pingFrom.logDir = $LogDir + "\$mode"
			$testResult = DoPingTest -pingFrom $pingFrom
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