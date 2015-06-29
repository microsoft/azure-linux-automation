Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
$duration = 600
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
	$hs1vm10 = $testVMsinService[9]
	$hs1vm10IP = $hs1vm10.IpAddress
	$hs1vm10Hostname = $hs1vm10.InstanceName	
	$hs1vm10Endpoints = $hs1vm10 | Get-AzureEndpoint
	$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
	$hs1vm10sshport = GetPort -Endpoints $hs1vm10Endpoints -usage ssh 
	
	Remove-Item hostnames.txt | Out-Null
	foreach($i in $testVMsinService)
	{
		$i.HostName >> hostnames.txt
	}
	foreach ($NumberofConnections in $SubtestValues) 
	{
		try
		{
			$testResult = $null
			LogMsg "Test Started for Parallel Connections $NumberofConnections"
			
			function UploadFiles()
			{
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm10sshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm10sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm10sshport -files hostnames.txt -username $user -password $password -upload 2>&1 | Out-Null
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm10sshport -command "dos2unix *" -runAsSudo 2>&1 | Out-Null
				return $true
			}
			if(!$filesUploaded)
			{
				$filesUploaded = UploadFiles
			}
			$TestStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm10sshport -command "bash $($currentTestData.testScript.Split(',')[0]) $user $password $($currentTestData.testScript.Split(',')[1]) $($currentTestData.testScript.Split(',')[2]) $NumberofConnections $duration" -runAsSudo -runmaxallowedtime 1200 -ignoreLinuxExitCode
			function CollectLogs()
			{
				
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm10sshport -command "mkdir logs" -runAsSudo 2>&1 | Out-Null
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm10sshport -command 'mv *.log *.txt logs/' -runAsSudo 2>&1 | Out-Null
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm10sshport -command "tar -cvf logs.tar logs" -runAsSudo 2>&1 | Out-Null
				$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/logs.tar" -downloadTo $LogDir -port $hs1vm10sshport -username $user -password $password 2>&1 | Out-Null
				return $true
			}
			if($TestStatus -imatch  "Mesh Network test Success")
			{
				LogMsg "Mesh network test completed Successfully.."
				$testResult = "PASS"
			}
			else
			{
				LogErr "Mesh network test failed.." 
				$testResult = "FAIL"
			}
			LogMsg "$($currentTestData.testName) : $NumberofConnections : $testResult"
		}
		catch
		{
			$ErrorMessage =  $_.Exception.Message
			LogMsg "EXCEPTION : $ErrorMessage"
		}
		Finally
		{
			$metaData = $NumberofConnections 
			if (!$testResult)
			{
				$testResult = "Aborted"
			}
			$resultArr += $testResult
			$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
		}
	}
	$logs = CollectLogs
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
return $result,$resultSummary