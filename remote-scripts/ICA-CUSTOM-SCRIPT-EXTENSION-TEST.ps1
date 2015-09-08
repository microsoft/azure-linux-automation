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
		$testServiceData = Get-AzureService -ServiceName $isDeployed

#Get VMs deployed in the service..
		$testVMsinService = $testServiceData | Get-AzureVM

		$hs1vm1 = $testVMsinService
		$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
		$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
		$hs1VIP = $hs1vm1Endpoints[0].Vip
		$hs1ServiceUrl = $hs1vm1.DNSName
		$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
		$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
		$lsOutput = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls /var/log/" -runAsSudo
		LogMsg -msg $lsOutput -LinuxConsoleOuput
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -cvzf /home/$user/AzureExtensionLogs.tar.gz /var/log/azure/*" -runAsSudo
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/AzureExtensionLogs.tar.gz" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		$varLogFolder = "/var/log"
		$lsOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls -lR $varLogFolder" -runAsSudo
		$LogFilesPaths = ""
		$LogFiles = ""
		$folderToSearch = "/var/log/azure"
		foreach ($line in $lsOut.Split("`n") )
		{
			if ($line -imatch $varLogFolder)
			{
				$currentFolder = $line.Replace(":","")
			}
			if ( ( ($line.Split(" ")[0][0])  -eq "-" ) -and ($currentFolder -imatch $folderToSearch) )
			{
				if ($LogFilesPaths)
				{
					$LogFilesPaths += "," + $currentFolder + "/" + $line.Split(" ")[8]
					$LogFiles += "," + $line.Split(" ")[8]
				}
				else
				{
					$LogFilesPaths = $currentFolder + "/" + $line.Split(" ")[8]
					$LogFiles += $line.Split(" ")[8]
				}
			}
		}
		RemoteCopy -download -downloadFrom $hs1VIP -files $LogFilesPaths -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		RemoteCopy -download -downloadFrom $hs1VIP -files "/var/log/waagent.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		if ($lsOutput -imatch "CustomExtensionSuccessful")
		{
			$testResult = "PASS"
		}
		else
		{
			$testResult = "FAIL"
			LogMsg "Please check logs."
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result
