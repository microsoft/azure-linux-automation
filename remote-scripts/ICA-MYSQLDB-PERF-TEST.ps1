# This script deploys the VMs for the Mariadb performance test and trigger test.
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
#
#####

<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

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
		
		$hs1vm2IP = $allVMData[1].InternalIP
		$hs1vm2Hostname = $allVMData[1].RoleName
		$hs1vm2sshport = $allVMData[1].SSHPort
		$hs1vm2tcpport = $allVMData[1].TCPtestPort
		$hs1vm2udpport = $allVMData[1].UDPtestPort

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mkdir code" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv *.sh code/" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x code/*" -runAsSudo

		$KernelVersionVM1 = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo 
		$KernelVersionVM2 = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "uname -a" -runAsSudo 
	
		LogMsg "VM is ready for netperf test"
		LogMsg "VM1 kernel version:- $KernelVersionVM1"
		LogMsg "VM2 kernel version:- $KernelVersionVM2"
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash /home/$user/code/$($currentTestData.testScript) $user $password $hs1vm2IP" -runAsSudo -runMaxAllowedTime 900
		$out_tail = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tail /home/$user/code/mysql_perf_log/mysql_perf_sysbench.log" -runAsSudo
		
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/code/mysql_perf_log/mysql_perf_sysbench.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		if ($out_tail -imatch "MYSQL_Perf_TEST_COMPLETED")
		{

			$consoleData = Get-Content -Path "$LogDir\mysql_perf_sysbench.log"
			foreach ($line in $consoleData)
			{
				if ($line -imatch "OLTP test statistics")
				{
					$printLogs = $true
				}
				if ($line -imatch "====== Completed Run")
				{
					$printLogs = $false
				}
				if ( $printLogs)
				{
					LogMsg $line -LinuxConsoleOuput
				}	
			}
			LogMsg "Test Completed succesfull"
			$testResult = "Passed"		}
		else{
			LogMsg "Test Failed.."
			$testResult = "Aborted"
		}
		LogMsg "Test result : $testResult"
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = ""
		if (!$testResult)
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
