<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$VMSizes = ($currentTestData.SubtestValues).Split(",")
$NumberOfSizes = $VMSizes.Count
$DeploymentCount = $currentTestData.DeploymentCount
#Test Starts Here..
	try
	{
        $count = 0
        $allowedFails = 5
        $successCount = 0
        $failCount = 0
        $VMSizeNumber = 0
		While ($count -lt $DeploymentCount)
        {
            $count += 1
            #Create A VM here and Wait for the VM to come up.
            LogMsg "ATTEMPT : $count/$DeploymentCount : Deploying $($VMSizes[$VMSizeNumber]) VM.."
            $isDeployed = DeployVMS -setupType $($VMSizes[$VMSizeNumber]) -Distro $Distro -xmlConfig $xmlConfig
            
            if ($isDeployed)
            {
                $successCount += 1

                LogMsg "ATTEMPT : $count/$DeploymentCount : Deploying $($VMSizes[$VMSizeNumber]) VM.. SUCCESS"
                $deployResult = "PASS"
                #M is Deployed. Delete the service.. 
            }
            else
            {
                $failCount += 1
                LogErr "ATTEMPT : $count/$DeploymentCount : Deploying $($VMSizes[$VMSizeNumber]) VM.. FAIL"
                $deployResult = "FAIL"
                if ( $failCount -lt $allowedFails )
                {
                    continue;
                }
                else
                {
                    break;
                }
            }
            if($VMSizeNumber -gt ($NumberOfSizes-2))
            {
                $VMSizeNumber = 0
            }
            else
            {
                $VMSizeNumber += 1
            }
            DoTestCleanUp -result $deployResult -testName $currentTestData.testName -deployedServices $isDeployed
        }
        if (($successCount -eq $DeploymentCount) -and ($failCount -eq 0))
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
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
        $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "DeploymentCount : $count/$DeploymentCount" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result, $resultSummary