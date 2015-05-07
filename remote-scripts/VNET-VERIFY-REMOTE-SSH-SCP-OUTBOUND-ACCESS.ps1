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
#Extract the VM information..
	$hsNames = $isDeployed
	$hsNames = $hsNames.Split("^")
	$hs1Name = $hsNames[0]
	$hs2Name = $hsNames[1]
	$hs3Name = $hsNames[2]
	$testService1Data = Get-AzureService -ServiceName $hs1Name
	$testService2Data =  Get-AzureService -ServiceName $hs2Name
	$externalServiceData = Get-AzureService -ServiceName $hs3Name
#Get VMs deployed in the service..
	$hs1vms = $testService1Data | Get-AzureVM
	$hs2vms = $testService2Data | Get-AzureVM
	$hs1vm1 = $hs1vms[0]
	$hs1vm2 = $hs1vms[1]
	$hs2vm1 = $hs2vms[0]
	$hs2vm2 = $hs2vms[1]

#Get the IP addresses
	$hs1vm1IP = $hs1vm1.IPaddress
	$hs1vm2IP = $hs1vm2.IPaddress
	$hs2vm1IP = $hs2vm1.IPaddress
	$hs2vm2IP = $hs2vm2.IPaddress
	$hs1vm1Hostname = $hs1vm1.InstanceName
	$hs1vm2Hostname = $hs1vm2.InstanceName
	$hs2vm1Hostname = $hs2vm1.InstanceName
	$hs2vm2Hostname = $hs2vm2.InstanceName
	$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
	$hs1vm2Endpoints = $hs1vm2 | Get-AzureEndpoint
	$hs2vm1Endpoints = $hs2vm1 | Get-AzureEndpoint
	$hs2vm2Endpoints = $hs2vm2 | Get-AzureEndpoint
	$hs1VIP = $hs1vm1Endpoints[0].Vip
	$hs2VIP = $hs2vm1Endpoints[0].Vip
	$hs1ServiceUrl = $hs1vm1.DNSName
	$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
	$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
	$hs2ServiceUrl = $hs2vm1.DNSName
	$hs2ServiceUrl = $hs2ServiceUrl.Replace("http://","")
	$hs2ServiceUrl = $hs2ServiceUrl.Replace("/","")
	$hs1vm1tcpport = GetPort -Endpoints $hs1vm1Endpoints -usage tcp
	$hs1vm2tcpport = GetPort -Endpoints $hs1vm2Endpoints -usage tcp
	$hs2vm1tcpport = GetPort -Endpoints $hs2vm1Endpoints -usage tcp
	$hs2vm2tcpport = GetPort -Endpoints $hs2vm2Endpoints -usage tcp
	$hs1vm1udpport = GetPort -Endpoints $hs1vm1Endpoints -usage udp
	$hs1vm2udpport = GetPort -Endpoints $hs1vm2Endpoints -usage udp
	$hs2vm1udpport = GetPort -Endpoints $hs2vm1Endpoints -usage udp
	$hs2vm2udpport = GetPort -Endpoints $hs2vm2Endpoints -usage udp
	$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh	
	$hs1vm2sshport = GetPort -Endpoints $hs1vm2Endpoints -usage ssh	
	$hs2vm1sshport = GetPort -Endpoints $hs2vm1Endpoints -usage ssh	
	$hs2vm2sshport = GetPort -Endpoints $hs2vm2Endpoints -usage ssh	
   	#Extract External Server Data
	$externalServer = $externalServiceData | Get-AzureVM
	$externalServerEndpoints = $externalServer | Get-AzureEndpoint
	$externalServerIP = $externalServerEndpoints[0].Vip
	$externalServerUrl = $externalServer.DNSName
	$externalServerUrl = $externalServerUrl.Replace("http://","")
	$externalServerUrl = $externalServerUrl.Replace("/","")
	$externalServerTcpport = GetPort -Endpoints $externalServerEndpoints -usage tcp
	$externalServerUdpport = GetPort -Endpoints $externalServerEndpoints -usage udp
	$externalServerSshport = GetPort -Endpoints $externalServerEndpoints -usage ssh
	
	LogMsg "Test Machine 1 : $hs1VIP : $hs1vm1sshport"
	LogMsg "Test Machine 2 : $hs1VIP : $hs1vm2sshport"
	LogMsg "Test Machine 3 : $hs2VIP : $hs2vm1sshport"
	LogMsg "Test Machine 4 : $hs2VIP : $hs2vm2sshport"
	LogMsg "External Machine : $externalServerIP : $externalServerSshport"

	$VnetVMSSHDetails = Get-SSHDetailofVMs -DeployedServices "$hs1Name^$hs2Name"
	$VnetVMHostnameDIPDetails = Get-AllVMHostnameAndDIP "$hs1Name^$hs2Name"
	$AllVMSSHDetails = Get-SSHDetailofVMs -DeployedServices $isDeployed
#endregion

#region CONFIGURE VNET VMS AND MAKE THEM READY FOR VNET TEST EXECUTION...
	try
	{
		$dnsServer = CreateVMNode -nodeIp '192.168.3.120' -nodeSshPort 22 -user root -password "redhat" -nodeHostname "ubuntudns"
		$intermediateVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -nodeDip $hs1vm1IP -nodeHostname $hs1vm1Hostname
		$externalServer = CreateVMNode -nodeIp $externalServerIP -nodeSshPort $externalServerSSHport -user $user -password $password
		ConfigureVNETVMs -SSHDetails $VnetVMSSHDetails
		UploadFilesToAllDeployedVMs -SSHDetails $AllVMSSHDetails  -files $currentTestData.files
		RunLinuxCmdOnAllDeployedVMs -SSHDetails $AllVMSSHDetails  -command "chmod +x *.py"
		#NO DNS CONFUGURATION NEEDED.
		#ConfigureDnsServer -intermediateVM $intermediateVM -DnsServer $dnsServer -HostnameDIPDetails $HostnameDIPDetails
		$isAllConfigured = "True"
	}
	catch
	{
		$isAllConfigured = "False"
		$ErrorMessage =  $_.Exception.Message
		LogErr "EXCEPTION : $ErrorMessage"   
	}
#endregion

#region TEST EXECUTION
	if ($isAllConfigured -eq "True")
	{
		$resultArr = @()
		foreach ($Value in $SubtestValues) 
		{
			mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
			$toVM = $externalServer
			switch ($Value)
			{
				"HS1VM1" {
					$FromVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -logDir $LogDir
				}
				"HS1VM2" {
					$FromVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -user $user -password $password -logDir $LogDir
				}
				"HS2VM1" {
					$FromVM = CreateVMNode -nodeIp $hs2VIP -nodeSshPort $hs2vm1sshport -user $user -password $password -logDir $LogDir
				}
				"HS2VM2" {
					$FromVM = CreateVMNode -nodeIp $hs2VIP -nodeSshPort $hs2vm2sshport -user $user -password $password -logDir $LogDir
				}
			}
			foreach ($mode in $currentTestData.TestMode.Split(","))
			{ 
				try
				{
					$testResult = ''

					mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null
					$FromVM.logDir = $LogDir + "\$Value\$mode"
					$ToVM.logDir = $LogDir + "\$Value\$mode"

					LogMsg "Test Started for $Value to Local VM in $mode mode.."

					if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
					{
						$sshResult = DoSSHTest -fromVM $FromVM -toVM $ToVM -command "$ifconfig_cmd" -runAsSudo
						$scpResult = DoSCPTest -fromVM $FromVM -toVM $ToVM -filesToCopy "/home/$user/azuremodules.py"

					}

					if(($mode -eq "URL") -or ($mode -eq "Hostname"))
					{
						$sshResult = DoSSHTest -fromVM $FromVM -toVM $ToVM -command "$ifconfig_cmd" -runAsSudo -hostnameMode
						$scpResult = DoSCPTest -fromVM $FromVM -toVM $ToVM -filesToCopy "/home/$user/azuremodules.py" -hostnameMode
					}
					LogMsg "SSH result : $sshResult"
					LogMsg "SCP result : $scpResult"
					if (($sshResult -eq "PASS") -and ($scpResult -eq "PASS"))
					{
						$testResult = "PASS"
					}
					else
					{
						$testResult = "FAIL"
					}

					LogMsg "for $Value in $mode mode - $testResult"
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
	}

	else
	{
		LogErr "Test Aborted due to Configuration Failure.."
		$testResult = "Aborted"
		$resultArr += $testResult
	}
#endregion

}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#region Clenup the DNS server.

#   THIS TEST DOESN'T REQUIRE DNS SERVER CLEANUP

#endregion

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result, $resultSummary
