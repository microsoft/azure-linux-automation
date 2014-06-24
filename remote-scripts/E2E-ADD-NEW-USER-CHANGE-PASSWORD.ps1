<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
#$isDeployed = "ICA-SmallVM-ORACLE-3-27-2-48-33"

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

        $newUser = "LinusTorvalds"
        $newPassword1 = "WhereIsMyPhone"
        $newPassword2 = "IDontKnowBuddy"
		$supressedOut = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		$supressedOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
        
        #Add New User Here..
        try
        {
            $userAddOutput = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./AddNewUser.sh -newUser $newUser -newPassword $newPassword1" -runAsSudo
            if ($userAddOutput -imatch "AUTOMATION_USER_ADDED")
            {
                $newUserAdded = $true
                Set-Content -Value $userAddOutput -Path $LogDir\userAddOutput.txt -Force
                LogMsg "Add new user : $newUser : SUCCESS"
                LogMsg "Password for : $newUser : $newPassword1"
            }
            else
            {
                $newUserAdded = $false
                LogErr "Add new user : $newUser : FAILED"
                LogErr "Output : $userAddOutput"
                $testResult = "FAIL"
            }
        }
        catch
        {
        $newUserAdded = $false
        LogErr "Add new user : $newUser : FAILED"
        $testResult = "ABORTED"
        }

        if($newUserAdded)
        {
		LogMsg "Now Changing the password of : $newUser."
        LogMsg "Uploading test scripts to new user home directory.."
        $supressedOut = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $newUser -password $newPassword1 -upload
		$supressedOut = RunLinuxCmd -username $newUser -password $newPassword1 -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *"
            try
            {
    		    $changePassout = RunLinuxCmd -username $newUser -password $newPassword1 -ip $hs1VIP -port $hs1vm1sshport -command "./ChangeUserPassword.sh -oldPassword $newPassword1 -newPassword $newPassword2"
                if ($changePassout -imatch "PASSWORD_CHANGED_SUCCESSFULLY")
                {
                    LogMsg "Password Changed for user : $newUser"
                    Set-Content -Value $changePassout -Path $LogDir\PasswordChangeOutput.txt -Force
                    try
                    {
                        $out2 = RunLinuxCmd -username $newUser -password $newPassword2 -ip $hs1VIP -port $hs1vm1sshport -command "echo Hello"
                        if ($out2 -imatch "Hello")
                        {
                            LogMsg "Password Change Verified."
                            $passwordChanged = $true

                        }
                        else
                        {
                            LogErr "Everything was successfult. But Unable to verify execution of command."
                            $passwordChanged = $false
                        }
                    }
                    catch
                    {
                        LogErr "No Error Detected while changing the password but unable to execute command using new password"
                        $passwordChanged = $false
                    }

                }
                else
                {
                    LogErr "No Error Detected while changing the password. But didn't got verification message."
                    LogErr $out
                    $passwordChanged = $false
                }
            }
            catch
            {
                LogErr "Failed to change the password for user : $newUser"
                $testResult =  "ABORTED"
            }
        }
        else
        {
            LogErr "Unable to Add new user - $newUser"
        }


        if ($newUserAdded -and $passwordChanged)
        {
            $testResult = "PASS"
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
