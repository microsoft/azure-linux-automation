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

        $newPassword = "LinuxOnAzure"
		$supressedOut = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		$supressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo


		LogMsg "Executing : $($currentTestData.testScript)"
        try
        {
    		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./$($currentTestData.testScript) -user $user -newPassword $newPassword -oldPassword $password"
            if ($out -imatch "updated successfully")
            {
                LogMsg "Password Changed for user : $user"
                try
                {
                    $out2 = RunLinuxCmd -username $user -password $newPassword -ip $hs1VIP -port $hs1vm1sshport -command "echo Hello"
                    if ($out2 -imatch "Hello")
                    {
                        LogMsg "Password Change Verified."
                        $testResult = "PASS"

                    }
                    else
                    {
                        LogErr "Everything was successfult. But Unable to verify execution of command."
                        $testResult = "FAIL"
                    }
                }
                catch
                {
                    LogErr "No Error Detected while changing the password but unable to execute command using new password"
                    $testResult = "FAIL"
                }

            }
            else
            {
                LogErr "No Error Detected while changing the password. But didn't got verification message."
                LogErr $out
                $testResult = "FAIL"
            }
        }
        catch
        {
            LogErr "Failed to change the password for user : $user"
            $testResult =  "FAIL"
        }
		LogMsg "Test result : $testResult"
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
