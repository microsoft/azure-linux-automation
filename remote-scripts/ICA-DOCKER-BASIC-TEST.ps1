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
		$clientVMData = $allVMData
		#region CONFIGURE VM FOR TERASORT TEST
		LogMsg "Test VM details :"
		LogMsg "  RoleName : $($clientVMData.RoleName)"
		LogMsg "  Public IP : $($clientVMData.PublicIP)"
		LogMsg "  SSH Port : $($clientVMData.SSHPort)"
		#
		# PROVISION VMS FOR LISA WILL ENABLE ROOT USER AND WILL MAKE ENABLE PASSWORDLESS AUTHENTICATION ACROSS ALL VMS IN SAME HOSTED SERVICE.	
		#
		ProvisionVMsForLisa -allVMData $allVMData -installPackagesOnRoleNames "none"
		#endregion

		
		#region EXECUTE TEST
        $StartScriptName = "test_docker.sh"
		RemoteCopy -uploadTo $clientVMData.PublicIP -port $clientVMData.SSHPort -files ".\remote-scripts\$StartScriptName" -username "root" -password $password -upload
		$out = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "chmod +x $StartScriptName"
		$dockerOutput = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -command "/root/$StartScriptName"
        #endregion
        
        RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "dockerServiceStatusLogs.txt"
        RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username "root" -password $password -download -downloadTo $LogDir -files "dockerVersion.txt"
        $dockerVersion = (Select-String -Path $LogDir\dockerVersion.txt -Pattern "Version")[0].Line.Trim().Split(":")[1].Trim()
        $goLangVersion = (Select-String -Path $LogDir\dockerVersion.txt -Pattern "Go version")[0].Line.Trim().Split(":")[1].Trim()
        
        if ($dockerOutput -imatch "DOCKER_VERIFIED_SUCCESSFULLY")
        {
            $testResult = "PASS"
        }
        else
        {
            $testResult = "FAIL"
        }
        $testSummary = $null

        $resultSummary +=  CreateResultSummary -testResult $dockerVersion -metaData "Docker Version" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
        $resultSummary +=  CreateResultSummary -testResult $goLangVersion -metaData "GoLang Version" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		#endregion
		LogMsg "Test result : $testResult"
		LogMsg "Test Completed"
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = "DOCKER RESULT"
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
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
return $result, $resultSummary
