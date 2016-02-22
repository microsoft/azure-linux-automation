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

#endregion

	try
	{
		$currentWindowsfiles = $currentTestData.files
		UploadFilesToAllDeployedVMs -SSHDetails $SSHDetails -files $currentWindowsfiles
		RunLinuxCmdOnAllDeployedVMs -SSHDetails $SSHDetails -command "chmod +x *"
		$isAllConfigured = "True"
#endregion
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

			foreach ($mode in $currentTestData.TestMode.Split(","))
			{ 
				$testResult = ""
				try
				{
					$udpServer = CreateIperfNode -nodeIp $externalServerIP -nodeSshPort $externalServerSSHport -user $user -password $password -nodeUdpPort $externalServerUDPport -nodeIperfCmd "$python_cmd start-server.py -i1 -p $externalServerUDPport -u yes && mv Runtime.log start-server.py.log"
					switch ($Value)
					{
						"HS1VM1" {
							$udpClient = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -nodeUdpPort $hs1vm1udpport
						}
						"HS1VM2" {
							$udpClient = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -user $user -password $password -nodeUdpPort $hs1vm2udpport
						}
						"HS2VM1" {
							$udpClient = CreateIperfNode -nodeIp $hs2VIP -nodeSshPort $hs2vm1sshport -user $user -password $password -nodeUdpPort $hs2vm1udpport
						}
						"HS2VM2" {
							$udpClient = CreateIperfNode -nodeIp $hs2VIP -nodeSshPort $hs2vm2sshport -user $user -password $password -nodeUdpPort $hs2vm2udpport
						}
					}

					if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
					{
						$udpClient.cmd  = "$python_cmd start-client.py -c $externalServerIP -i1 -p $externalServerUDPport -t10 -u yes -l 1420"
						$expectedResult = "PASS"
					}

					if(($mode -eq "URL") -or ($mode -eq "Hostname"))
					{
						$udpClient.cmd  = "$python_cmd start-client.py -c $externalServerURL -i1 -p $externalServerUDPport -t10 -u yes -l 1420"
						$expectedResult = "FAIL"
					}
					LogMsg "Test Started for $Value in $mode mode.."

					mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null
					$udpServer.logDir = $LogDir + "\$Value\$mode"
					$udpClient.logDir = $LogDir + "\$Value\$mode"

					$testResult = IperfClientServerUDPDatagramTest -server $udpServer -client $udpClient -VNET
					LogMsg "testResult = $testResult"
					
					#$testResult = "PASS"
					
					if(($mode -eq "URL") -or ($mode -eq "Hostname"))
					{
					$expectedResult = "FAIL"
						if ($expectedResult -eq $testResult)
						{
							LogMsg "Expected iperf resutl : FAIL. Got the iperf result : FAIL. Hence marking this test as PASS"
							$testResult = "PASS"
						}
						else
						{
							$testResult = "FAIL"
						}
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
