Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{
	$hs1Name = $isDeployed
	$testServiceData = Get-AzureService -ServiceName $hs1Name
	#Get VMs deployed in the service..
	$testVMsinService = $testServiceData | Get-AzureVM
	$hs1vm1 = $testVMsinService[0]
	$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
	$hs1VIP = $hs1vm1Endpoints[0].Vip
	$hs1ServiceUrl = $hs1vm1.DNSName
	$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
	$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
	$hs1vm1IP = $hs1vm1.IpAddress
	$hs1vm1Hostname = $hs1vm1.InstanceName
	$hs1vm2 = $testVMsinService[1]
	$hs1vm2IP = $hs1vm2.IpAddress
	$hs1vm2Hostname = $hs1vm2.InstanceName	
	$hs1vm2Endpoints = $hs1vm2 | Get-AzureEndpoint
	$hs1vm1tcpport = GetPort -Endpoints $hs1vm1Endpoints -usage tcp
	$hs1vm2tcpport = GetPort -Endpoints $hs1vm2Endpoints -usage tcp
	$hs1vm1udpport = GetPort -Endpoints $hs1vm1Endpoints -usage udp
	$hs1vm2udpport = GetPort -Endpoints $hs1vm2Endpoints -usage udp
	$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
	$hs1vm2sshport = GetPort -Endpoints $hs1vm2Endpoints -usage ssh
	try
	{
		$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files1 -username $user -password $password -upload 2>&1 | Out-Null
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "apt-get install -y iperf3 dos2unix sshpass" -runAsSudo 2>&1 | Out-Null
		$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm2sshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "apt-get install -y iperf3 dos2unix sshpass" -runAsSudo 2>&1 | Out-Null
		$IsServerStarted = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./$($currentTestData.testScript.Split(',')[0])" -runAsSudo -ignoreLinuxExitCode
		if ($IsServerStarted -imatch "not running")
		{
			LogErr "Iperf3 server not started .." 
		}
		else
		{
			LogMsg "iperf server is running and available from 8001 to 8100 ports" 
			$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "./$($currentTestData.testScript.Split(',')[1]) $hs1vm1IP  > perf-client.log" -runAsSudo -runmaxallowedtime 15000 -ignoreLinuxExitCode
			$status = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "cat /home/$user/teststatus.txt" -runAsSudo -ignoreLinuxExitCode				
			if(($status -imatch "IPERF test completed") -and ($status -imatch "CSV test completed") -and ($status -imatch "PERF test completed"))
			{
				$testResult = "PASS"
				$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/logs.tar,/home/$user/teststatus.txt" -downloadTo $LogDir -port $hs1vm2sshport -username $user -password $password 2>&1 | Out-Null
			}
			else{
				$testResult = "FAIL"
			}
		}
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
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result