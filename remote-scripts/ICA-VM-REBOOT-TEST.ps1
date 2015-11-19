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
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
        $hs1vm1Hostname = $AllVMData.RoleName

        $rebootCount = $($currentTestData.rebootCount)
        $count = 1
        $restartMethod = "Restart"
        while ( $count -le $rebootCount )
        {
            
            if ( $restartMethod -eq "Restart" )
            {
                $restartMethod = "StopAndStart"
                LogMsg "[$count/$rebootCount] Restarting $hs1vm1Hostname ..."    
                $restartStatus = Restart-AzureVM -ServiceName $isDeployed -Name $hs1vm1Hostname -Verbose
                $restartStatus = $restartStatus.OperationStatus
            }
            else
            {
                $restartMethod = "Restart"
                LogMsg "[$count/$rebootCount] Step1. Stoping $hs1vm1Hostname ..."    
                $stopVMStauts = Stop-AzureVM -ServiceName $isDeployed -Name $hs1vm1Hostname -Verbose -StayProvisioned -Force
                if ( $stopVMStauts.OperationStatus -eq "Succeeded" )
                {
                    LogMsg "[$count/$rebootCount] Step2. Starting $hs1vm1Hostname ..."    
                    $startVMStautus = Start-AzureVM -ServiceName $isDeployed -Name $hs1vm1Hostname -Verbose
                    if ( $startVMStautus.OperationStatus -eq "Succeeded" )
                    {
                        $restartStatus = $startVMStautus.OperationStatus
                    }
                    else
                    {
                        $restartStatus = "Failed"
                    }
                }
                else
                {
                    $restartStatus = "Failed"
                }
            }
            if ( $restartStatus -eq "Succeeded" )
            {
                    LogMsg "VM restarted successfully"
                    $sshStatus = isAllSSHPortsEnabledRG -AllVMDataObject $AllVMData


                if ( $sshStatus -eq "True" )
                {
                    LogMsg "SSH connection verified"
                    $testResult = "PASS"
                    $count += 1
                }
                else
                {
                    LogErr "SSH connection failed."
                    $testResult = "FAIL"
                    break
                }
            }
            else
            {
                LogErr "Failed to restart VM"
                $testResult = "FAIL"
                break
            }
        }
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result