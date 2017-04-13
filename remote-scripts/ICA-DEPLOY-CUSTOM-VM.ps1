<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType (Get-Content .\currentDeploymentType.txt) -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{

	try
	{
        LogMsg "Your VMs are ready to use..."
        $counter = 1
        if ($UseAzureResourceManager)
        {
            $ResourceType = "Resource Group"
        }
        else
        {
            $ResourceType = "Hosted Service"
        }
        #https://ms.portal.azure.com/#resource/subscriptions/2cd20493-fe97-42ef-9ace-ab95b63d82c4/resourceGroups/asixiao-jenkins-HS-TwoVMs-Linux-10-26-125028/overview
        foreach ( $item in $isDeployed.Split("^") )
        {
            $resultSummary +=  CreateResultSummary -testResult "$item" -metaData "$ResourceType" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
            $subID = $($xmlConfig.config.Azure.General.SubscriptionID)
            $subID = $subID.Trim()
            $resultSummary +=  CreateResultSummary -testResult "https://ms.portal.azure.com/#resource/subscriptions/$subID/resourceGroups/$item/overview" -metaData "WebURL" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
        }
        foreach ( $vm in $allVMData )
        {
            
            if ( $GuestOS -imatch "Linux" )
            {
                LogMsg "VM #$counter`: $($vm.PublicIP):$($vm.SSHPort)"
                $resultSummary +=  CreateResultSummary -testResult "$($vm.Status)" -metaData "VM #$counter` : $($vm.PublicIP) : $($vm.SSHPort) " -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
            }
            else
            {
                LogMsg "VM #$counter`: $($vm.PublicIP):$($vm.RDPPort)"
                $resultSummary +=  CreateResultSummary -testResult "$($vm.Status)" -metaData "VM #$counter` : $($vm.PublicIP) : $($vm.RDPPort) " -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
            }
            $counter++
        }
		LogMsg "Test Result : PASS."
		$testResult = "PASS"
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

	}   
}

else
{
    LogErr "Something went wrong in the Deployment."
	$testResult = "FAIL"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed 

#Return the result and summery to the test suite script..
return $result,$resultSummary
