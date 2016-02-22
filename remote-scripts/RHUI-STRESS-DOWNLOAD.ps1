<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$testResult1 = ""
$testResult2 = ""
$resultArr = @()

Function RetryStartTest($vmuser, $vmpassword, $vmvip, $vmport)
{
	$out = '0'
	while ($out -ne '1')
	{
		RunLinuxCmd -username $vmuser -password $vmpassword -ip $vmvip -port $vmport -command "python $($currentTestData.entrytestScript) -d $($currentTestData.parameters.duration) -p $($currentTestData.parameters.pkg) -t $($currentTestData.parameters.timeout) -s" -runAsSudo
		sleep 5
		$out = RunLinuxCmd -username $vmuser -password $vmpassword -ip $vmvip -port $vmport -command "cat Runtime.log | grep -i 'red hat' | wc -l"
	}
}

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
		# start test
		foreach($vm in $allVMData)
		{
			$hs1VIP = $vm.PublicIP
			$hs1ServiceUrl = $vm.URL
			$hs1vm1IP = $vm.InternalIP
			$hs1vm1Hostname = $vm.RoleName
			$hs1vm1sshport = $vm.SSHPort
			$hs1vm1tcpport = $vm.TCPtestPort
			$hs1vm1udpport = $vm.UDPtestPort
			
			RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
			LogMsg "Executing : $($currentTestData.entrytestScript)"
	        RetryStartTest -vmuser $user -vmpassword $password -vmvip $hs1VIP -vmport $hs1vm1sshport
		}

		# waiting for the end
		LogMsg "RHUI stress testing is running..."
		sleep $currentTestData.parameters.duration
		sleep 100

		# get results
		$results = @{}
		$status = @{}
		foreach($vm in $allVMData)
		{
			$hs1VIP = $vm.PublicIP
			$hs1ServiceUrl = $vm.URL
			$hs1vm1IP = $vm.InternalIP
			$hs1vm1Hostname = $vm.RoleName
			$hs1vm1sshport = $vm.SSHPort
			$hs1vm1tcpport = $vm.TCPtestPort
			$hs1vm1udpport = $vm.UDPtestPort

			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Runtime.log $($currentTestData.testScript).log" -runAsSudo
			RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/state.txt, /home/$user/Summary.log, /home/$user/$($currentTestData.testScript).log, /home/$user/download*.log" -downloadTo $LogDir\$hs1vm1Hostname -port $hs1vm1sshport -username $user -password $password
			$runtimelog1 = Get-Content $LogDir\$hs1vm1Hostname\$($currentTestData.testScript).log
			$ver1 = $runtimelog1.Split("`n") | Where-Object {$_.contains("TEST START FOR")} | %{$_.split(" ")[-1].Replace('-','')}
			$testResult1 = Get-Content $LogDir\$hs1vm1Hostname\Summary.log
			$testStatus1 = Get-Content $LogDir\$hs1vm1Hostname\state.txt
			$results.Add($ver1,$testResult1)
			$status.Add($ver1,$testStatus1)
		}
		
		LogMsg "Test result:"
		$results.Keys | % { LogMsg "RHEL $_ : $($results[$_])"}
		LogMsg "Test status:"
		$status.Keys | % { LogMsg "RHEL $_ : $($status[$_])"}

		if('FAIL' -in $results.Values) 
		{
			$testResult = 'FAIL'
		}
		else 
		{
		   	$testResult = 'PASS'
		}
	}

	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = ""
		$results.Values | % { if(!$_) { $testResult = "Aborted"; break }}
		$resultArr += $testResult
#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
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
