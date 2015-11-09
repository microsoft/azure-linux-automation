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

#region CONFIGURE VNET VMS AND MAKE THEM READY FOR VNET TEST EXECUTION...
		# NO PRECONFIGURATION NEEDED FOR THIS TEST.
		$isAllConfigured = "True"
#endregion

#region TEST EXECUTION
	if ($isAllConfigured -eq "True")
	{
		try
		{
			$ErrCount = 0
			foreach ($vmData in $allVMData)
			{
				LogMsg "Checking : $($vmData.Rolename)"
				$out = RunLinuxCmd -ip $vmData.PublicIP -port $vmData.SSHPort -username $user -password $password -command "$ifconfig_cmd -a" -runAsSudo
				LogMsg $out -LinuxConsoleOuput
				if ($out -imatch $vmData.InternalIP)
				{
					LogMsg "Expected DIP : $($vmData.InternalIP); Recorded DIP : $($vmData.InternalIP);"
					LogMsg "$($vmData.Rolename) has correct DIP.."
				}
				else
				{
					LogErr "INCORRECT DIP DETAIL : $($vmData.Rolename)"
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

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result