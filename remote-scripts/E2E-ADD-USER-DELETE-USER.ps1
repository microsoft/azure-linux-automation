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
		LogMsg "Now deleting user : $newUser."
            try
            {
    		    $DeleteUserOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./DeleteUser.sh -duser $newUser" -runAsSudo
                if ($DeleteUserOut -imatch "AUTOMATION_USER_DELETED")
                {
                    LogMsg "User deleted successfully : $newUser"
                    Set-Content -Value $DeleteUserOut -Path $LogDir\DeleteUserOutput.txt -Force
                    $isUserDeleted = $true
                }
                else
                {
                    LogErr "Failed to delete user. Check logs please."
                    LogErr $DeleteUserOut
                    $isUserDeleted = $false
                    $testResult = "FAIL"
                }
            }
            catch
            {
                LogErr "Failed to delete user : $newUser"
                $testResult =  "ABORTED"
            }
        }
        else
        {
            LogErr "Unable to Add new user - $newUser"
            $isUserDeleted = $false
        }


        if ($newUserAdded -and $isUserDeleted)
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
