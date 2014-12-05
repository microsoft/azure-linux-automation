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
        
        $linpackToolsWebLocation = "http://registrationcenter.intel.com/irc_nas/4547/l_lpk_p_11.2.0.003.tgz"
        $linpackFile = "l_lpk_p_11.2.0.003.tgz"
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -rf *" -runAsSudo
        $out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
        #Download linpack libraries to VM..
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "wget $linpackToolsWebLocation"
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -xvzf $linpackFile"
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cp -ar linpack_11.2.0/benchmarks/linpack/* ./" -runAsSudo
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python start-linpack-test-in-background.py" -runAsSudo
        $linuxPids = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ps -ef | awk '/runme_xeon64/ && !/awk/ { print `$2 }'"
        if ($linuxPids.Length -ne 0)
        {
            LogMsg "Linpack tests are started in background..."
            $linuxPids = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ps -ef | awk '/runme_xeon64/ && !/awk/ { print `$2 }'"
            While ($linuxPids.Length -ne 0)
            {
                WaitFor -seconds 30
                $linuxPids = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ps -ef | awk '/runme_xeon64/ && !/awk/ { print `$2 }'"
            }
            $linpackOutput = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat runme_xeon64_console_output.txt"
            if ( $linpackOutput -imatch "Residual checks PASSED" )
            {
                $testResult = "PASS"
            }
            else
            {
                $testResult = "FAIL"
            }
        }
        else
        {
            LogErr "Failed to start LINPACK tests."
            $testResult = "ABORTED"
        }
        
        RemoteCopy -download -downloadFrom $hs1VIP -files "runme_xeon64_console_output.txt" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
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