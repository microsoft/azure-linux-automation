<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{
	#region EXTRACT ALL INFORMATION ABOUT DEPLOYED VMs
	$allVnetData = GetVNETDetailsFromXMLDeploymentData -deploymentType $currentTestData.setupType
	$vnetName = $allVnetData[0]
	$subnet1Range = $allVnetData[1]
	$subnet2Range = $allVnetData[2]
	$vnetDomainDBFilePath = $allVnetData[3]
	$vnetDomainRevFilePath = $allVnetData[4]
	$dnsServerIP = $allVnetData[5]

	$hs1vm1IP = $allVMData[0].InternalIP
	$hs1vm2IP = $allVMData[1].InternalIP
	$hs2vm1IP = $allVMData[2].InternalIP
	$hs2vm2IP = $allVMData[3].InternalIP

	$hs1vm1Hostname = $allVMData[0].RoleName
	$hs1vm2Hostname = $allVMData[1].RoleName
	$hs2vm1Hostname = $allVMData[2].RoleName
	$hs2vm2Hostname = $allVMData[3].RoleName

	$hs1VIP = $allVMData[0].PublicIP
	$hs2VIP = $allVMData[2].PublicIP

	$hs1ServiceUrl = $allVMData[0].URL
	$hs2ServiceUrl = $allVMData[2].URL

	$hs1vm1sshport = $allVMData[0].SSHPort
	$hs1vm2sshport = $allVMData[1].SSHPort
	$hs2vm1sshport = $allVMData[2].SSHPort
	$hs2vm2sshport = $allVMData[3].SSHPort

	$hs1vm1tcpport = $allVMData[0].TCPtestPort
	$hs1vm2tcpport = $allVMData[1].TCPtestPort
	$hs2vm1tcpport = $allVMData[2].TCPtestPort
	$hs2vm2tcpport = $allVMData[3].TCPtestPort

	$hs1vm1udpport = $allVMData[0].UDPtestPort
	$hs1vm2udpport = $allVMData[1].UDPtestPort
	$hs2vm1udpport = $allVMData[2].UDPtestPort
	$hs2vm2udpport = $allVMData[3].UDPtestPort
	
	$externalServerIP = $allVMData[4].PublicIP
	$externalServerTcpport = $allVMData[4].TCPtestPort
	$externalServerUdpport = $allVMData[4].UDPtestPort
	$externalServerSshport = $allVMData[4].SSHPort
	$externalServerURL = $allVMData[4].URL

	$SSHDetails = ""
	foreach ($vmData in $allVMData)
	{
		if($SSHDetails)
		{
			$SSHDetails = $SSHDetails + "^$($vmData.PublicIP)" + ':' +"$($vmData.SSHPort)"
		}
		else
		{
			$SSHDetails = "$($vmData.PublicIP)" + ':' +"$($vmData.SSHPort)"
		}
	}	
		
	LogMsg "Test Machine 1 : $hs1VIP : $hs1vm1sshport"
	LogMsg "Test Machine 2 : $hs1VIP : $hs1vm2sshport"
	LogMsg "Test Machine 3 : $hs2VIP : $hs2vm1sshport"
	LogMsg "Test Machine 4 : $hs2VIP : $hs2vm2sshport"
	LogMsg "External Machine : $externalServerIP : $externalServerSshport"

	try
	{
		$currentWindowsfiles = $currentTestData.files
		UploadFilesToAllDeployedVMs -SSHDetails $SSHDetails -files $currentWindowsfiles 
		RunLinuxCmdOnAllDeployedVMs -SSHDetails $SSHDetails -command "chmod +x *.py"
		$isAllConfigured = "True"
	}
	catch
	{
		$isAllConfigured = "False"
		$ErrorMessage =  $_.Exception.Message
		LogErr "EXCEPTION : $ErrorMessage"   
	}

	if ($isAllConfigured -eq "True")
	{
#region TEST EXECUTION  
		$resultArr = @()
		foreach ($Value in $SubtestValues) 
		{
			mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
			switch ($Value)
			{
				"HS1VM1" {
					$pingFrom = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -logDir $LogDir
				}
				"HS1VM2" {
					$pingFrom = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -user $user -password $password -logDir $LogDir
				}
				"HS2VM1" {
					$pingFrom = CreateVMNode -nodeIp $hs2VIP -nodeSshPort $hs2vm1sshport -user $user -password $password -logDir $LogDir
				}
				"HS2VM2" {
					$pingFrom = CreateVMNode -nodeIp $hs2VIP -nodeSshPort $hs2vm2sshport -user $user -password $password -logDir $LogDir
				}
			}
			foreach ($mode in $currentTestData.TestMode.Split(","))
			{ 
				try
				{

					if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
					{
						$pingFrom.cmd = "$python_cmd ping.py -x $externalServerIP -c 10"
					}

					if(($mode -eq "URL") -or ($mode -eq "Hostname"))
					{
						$pingFrom.cmd = "$python_cmd ping.py -x  $externalServerUrl  -c 10"
					}
					LogMsg "Test Started for $Value in $mode mode.."

					mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null
					$pingFrom.logDir = $LogDir + "\$Value\$mode"

					$testResult = DoPingTest -pingFrom $pingFrom -isVNET

					if ($testResult -eq "FAIL")
					{
						$testResult = "PASS"
					}

					LogMsg "Test Status for $mode mode - $testResult"
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
#endregion
	}
	else
	{
		LogErr "Test Aborted due to Configuration Failure.."
		$testResult = "Aborted"
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result , $resultSummary
