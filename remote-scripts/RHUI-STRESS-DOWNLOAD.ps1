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

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RemoteCopy -uploadTo $hs2VIP -port $hs2vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs2VIP -port $hs2vm1sshport -command "chmod +x *" -runAsSudo

		LogMsg "Executing : $($currentTestData.entrytestScript) on both RHEL6 and RHEL7"

        RetryStartTest -vmuser $user -vmpassword $password -vmvip $hs1VIP -vmport $hs1vm1sshport
		RetryStartTest -vmuser $user -vmpassword $password -vmvip $hs2VIP -vmport $hs2vm1sshport

		LogMsg "RHUI stress testing is running..."
		sleep $currentTestData.parameters.duration
		sleep 20
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Runtime.log $($currentTestData.testScript).log" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs2VIP -port $hs2vm1sshport -command "mv Runtime.log $($currentTestData.testScript).log" -runAsSudo
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/state.txt, /home/$user/Summary.log, /home/$user/$($currentTestData.testScript).log" -downloadTo $LogDir\$hs1vm1Hostname -port $hs1vm1sshport -username $user -password $password
		RemoteCopy -download -downloadFrom $hs2VIP -files "/home/$user/state.txt, /home/$user/Summary.log, /home/$user/$($currentTestData.testScript).log" -downloadTo $LogDir\$hs2vm1Hostname -port $hs2vm1sshport -username $user -password $password

		$runtimelog1 = Get-Content $LogDir\$hs1vm1Hostname\$($currentTestData.testScript).log
		$runtimelog2 = Get-Content $LogDir\$hs2vm1Hostname\$($currentTestData.testScript).log
		$ver1 = $runtimelog1.Split("`n")[0].split(" ")[-1].Replace('-','')
		$ver2 = $runtimelog2.Split("`n")[0].split(" ")[-1].Replace('-','')
		$testResult1 = Get-Content $LogDir\$hs1vm1Hostname\Summary.log
		$testStatus1 = Get-Content $LogDir\$hs1vm1Hostname\state.txt
		$testResult2 = Get-Content $LogDir\$hs2vm1Hostname\Summary.log
		$testStatus2 = Get-Content $LogDir\$hs2vm1Hostname\state.txt
		
		LogMsg "Test result:"
		LogMsg "RHEL${ver1}: $testResult1"
		LogMsg "RHEL${ver2}: $testResult2"

		if (($testResult1 -eq 'PASS') -and ($testResult2 -eq 'PASS'))
		{
			$testResult = 'PASS'
		}
		else 
		{
		 	$testResult = 'FAIL'   
		}

		if (($testStatus1 -eq "TestCompleted"))
		{
			LogMsg "Test Completed on RHEL$ver1"
		}
		else 
		{
			LogMsg "Test is not completed on RHEL$ver1"  
		}

		if ($testStatus2 -eq "TestCompleted")
		{
			LogMsg "Test Completed on RHEL$ver2"
		}
		else 
		{
			LogMsg "Test is not completed on RHEL$ver2"  
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
		if ((!$testResult1) -or (!$testResult2))
		{
			$testResult = "Aborted"
		}
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
