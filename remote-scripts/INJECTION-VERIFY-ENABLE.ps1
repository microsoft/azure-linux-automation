<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

# $isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
$isDeployed = "ICA-BVTDeployment-Ubuntu1404-5-15-15-7-44"
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

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo

		$DiskName = (Get-AzureVM $isDeployed | Get-AzureOSDisk).DiskName
		$subscriptionId = $xmlConfig.config.Azure.General.SubscriptionID
		$mgmtEndPoint = $xmlConfig.config.Azure.General.ManagementPortalUrl
		
		LogMsg "Updating Role handler XML"
		$configuration = "$pwd\Agent-Injection\role-update-handler.xml"
		[xml]$xml = New-Object XML
		$xml.Load($configuration)
		LogMsg $xml
		$xml.PersistentVMRole.OSVirtualHardDisk.DiskName = $DiskName
		$outputPath = "$pwd\temp\CI\$isDeployed.xml"
		$xml.Save($outputPath)

		$restUri = "$mgmtEndPoint/$subscriptionId/services/hostedservices/$isDeployed/deployments/$isDeployed/roles/" + $hs1vm1.InstanceName
		LogMsg $restUri
		$command = {$output = cmd.exe /c ".\tools\curl.exe -kv -X `"PUT`" -H `"x-ms-version: 2014-04-01`" -H `"Content-Type: application/xml`" -E .\Agent-Injection\cert.pem: -d@.\temp\CI\$isDeployed.xml $restUri 2>&1"; write-host $output; write-host "konka"; write-host ($output -match "202 Accepted"); if ($output -match "202 Accepted"){return "Accepted"} else {return "Failed"}}
		LogMsg "Executing command: $command"

		RetryOperation $command -expectesult "Accepted" -maxRetryCount 5

		LogMsg "Executing : $($currentTestData.testScript)"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./$($currentTestData.testScript)" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Runtime.log $($currentTestData.testScript).log" -runAsSudo
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/test/state.txt, /home/test/Summary.log, /home/test/$($currentTestData.testScript).log,/var/log/waagent.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		$testResult = Get-Content $LogDir\Summary.log
		$testStatus = Get-Content $LogDir\state.txt
		LogMsg "Test result : $testResult"

		if ($testStatus -eq "TestCompleted")
		{
			LogMsg "Test Completed"
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
