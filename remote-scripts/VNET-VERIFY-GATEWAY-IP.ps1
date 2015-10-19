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
	#endregion

	#NO DNS SERVER CONFIGURATION NEEDED FOR THIS TEST.
	$isAllConfigured = "True"
#endregion

#region TEST EXECUTION
	if ($isAllConfigured -eq "True")
	{
		try
		{
			#ConfigureVNETVMs -SSHDetails $SSHDetails -vnetDomainDBFilePath $vnetDomainDBFilePath -dnsServerIP $dnsServerIP
			$ErrCount = 0
			foreach ($VM in $allVMData)
			{
				LogMsg "Checking Gateway : $($VM.RoleName)"
				$currentVMGateway = RunLinuxCmd -ip $VM.PublicIP -port $VM.SSHPort -username $user -password $password -command "route" -runAsSudo
				$currentVMDIP = $VM.InternalIP
				$currentVMDIPSubnet = DetectSubnet -inputString $currentVMDIP -subnet1CIDR $subnet1Range -subnet2CIDR $subnet2Range
				$currentVMGatewaySubnet = DetectSubnet -inputString $currentVMGateway -subnet1CIDR $subnet1Range -subnet2CIDR $subnet2Range
				LogMsg "DIP subnet subnet detected : $currentVMDIPSubnet"
				LogMsg "Gateway subnet detected	: $currentVMGatewaySubnet"
				if ($currentVMDIPSubnet -eq $currentVMGatewaySubnet)
				{
					LogMsg "PASS"
				}
				else
				{
					LogErr "FAIL"
					$ErrCount = $ErrCount + 1
				}
			}

			if ($ErrCount -eq 0)
			{
				$testResult = "PASS"
			}
			else 
			{
				$testResult = "FAIL"
			}
			LogMsg "Test Result : $testResult"
		}
		catch
		{
			$ErrorMessage =  $_.Exception.Message
			LogErr "EXCEPTION : $ErrorMessage"   
		}
		Finally
		{
			$metaData = ""
			if (!$testResult)
			{
				$testResult = "Aborted"
			}
			$resultArr += $testResult
			$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
