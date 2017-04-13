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

	$SSHDetails = ""
	$HostnameDIPDetails = ""
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
		$VMhostname = $vmData.RoleName
		$VMDIP = $vmData.InternalIP
		if($HostnameDIPDetails)
		{
			$HostnameDIPDetails = $HostnameDIPDetails + "^$VMhostname" + ':' +"$VMDIP"
		}
		else
		{
			$HostnameDIPDetails = "$VMhostname" + ':' +"$VMDIP"
		}
	}	
	#endregion

#region CONFIGURE VNET VMS AND MAKE THEM READY FOR VNET TEST EXECUTION...
	try
	{
		ConfigureVNETVms -SSHDetails $SSHDetails -vnetDomainDBFilePath $vnetDomainDBFilePath -dnsServerIP $dnsServerIP
		UploadFilesToAllDeployedVMs -SSHDetails $SSHDetails -files $currentTestData.files
		RunLinuxCmdOnAllDeployedVMs -SSHDetails $SSHDetails -command "chmod +x *.py"		
		if ($UseAzureResourceManager)
		{
			$dnsServer = CreateVMNode -nodeIp "192.168.3.120" -nodeSshPort 22 -user "root" -password "redhat" -nodeHostname "dns-srv-01-arm"
			$nfsServer = CreateVMNode -nodeIp "192.168.3.125" -nodeSshPort 22 -user "root" -password "redhat" -nodeHostname "nfs-srv-01-arm"
			$mysqlServer = CreateVMNode -nodeIp "192.168.3.127" -nodeSshPort 22 -user "root" -password "redhat" -nodeHostname "mysql-srv-01-arm"
		}
		else
		{
			$dnsServer = CreateVMNode -nodeIp "192.168.3.120" -nodeSshPort 22 -user "root" -password "redhat" -nodeHostname "ubuntudns"
			$nfsServer = CreateVMNode -nodeIp "192.168.3.125" -nodeSshPort 22 -user "root" -password "redhat" -nodeHostname "ubuntunfsserver"
			$mysqlServer = CreateVMNode -nodeIp "192.168.3.127" -nodeSshPort 22 -user "root" -password "redhat" -nodeHostname "ubuntumysql"
		}
		$intermediateVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -nodeDip $hs1vm1IP -nodeHostname $hs1vm1Hostname
		$currentLinuxFiles = ConvertFileNames -ToLinux -currentWindowsFiles $currentTestData.files -expectedLinuxPath "/home/$user"
		RemoteCopyRemoteVM -upload -intermediateVM $intermediateVM -remoteVM $dnsServer  -remoteFiles $currentLinuxFiles
		RunLinuxCmdOnRemoteVM -intermediateVM $intermediateVM -remoteVM $dnsServer -remoteCommand "chmod +x /home/$user/*.py" -runAsSudo
		#Configure DNS Server
		ConfigureDnsServer -intermediateVM $intermediateVM -DnsServer $dnsServer -HostnameDIPDetails $HostnameDIPDetails -vnetDomainDBFilePath $vnetDomainDBFilePath -vnetDomainREVFilePath $vnetDomainRevFilePath
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
			switch ($Value)
			{
				"SameHS-DiffSubnet" {
					$FromVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -nodeDip $hs1vm1IP -nodeHostname $hs1vm1Hostname -logDir $LogDir
					$ToVM = CreateVMNode -nodeIp $hs1vm2IP -nodeSshPort 22 -user $user -password $password -nodeHostname $hs1vm2Hostname -logDir $LogDir
				}
				"DiffHS-SameSubnet" {
					$FromVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -user $user -password $password -nodeDip $hs1vm2IP -nodeHostname $hs1vm2Hostname -logDir $LogDir
					$ToVM = CreateVMNode -nodeIp $hs2vm1IP -nodeSshPort 22 -user $user -password $password -nodeHostname $hs2vm1Hostname -logDir $LogDir
				}
				"DiffHS-DiffSubnet" {
					$FromVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -nodeDip $hs1vm1IP -nodeHostname $hs1vm1Hostname -logDir $LogDir
					$ToVM = CreateVMNode -nodeIp $hs2vm2IP -nodeSshPort 22 -user $user -password $password -nodeHostname $hs1vm2Hostname -logDir $LogDir
				}
			}
			foreach ($mode in $currentTestData.TestMode.Split(","))
			{ 
				try
				{
					mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null
					$FromVM.logDir = $LogDir + "\$Value\$mode"
					$ToVM.logDir = $LogDir + "\$Value\$mode"
					LogMsg "Test Started for $Value in $mode mode.."

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
$dnsServer.cmd = "/home/$user/CleanupDnsServer.py -D $vnetDomainDBFilePath -r $vnetDomainRevFilePath"
RunLinuxCmdOnRemoteVM -intermediateVM $intermediateVM -remoteVM $dnsServer -runAsSudo -remoteCommand $dnsServer.cmd
#endregion
#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed
#Return the result and summery to the test suite script..
return $result, $resultSummary
