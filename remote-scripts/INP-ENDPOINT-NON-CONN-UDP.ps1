Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{    
    $hs1Name = $isDeployed
    $testServiceData = Get-AzureService -ServiceName $hs1Name

    #Get VMs deployed in the service..
    $testVMsinService = $testServiceData | Get-AzureVM

    $hs1vm1 = $testVMsinService
    $hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint

    $hs1VIP = $hs1vm1Endpoints[0].Vip
    $hs1ServiceUrl = $hs1vm1.DNSName
    $hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
    $hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")

    $hs1vm1tcpport = GetPort -Endpoints $hs1vm1Endpoints -usage tcp
    $dtapServerTcpport = "750"
    $hs1vm1udpport = GetPort -Endpoints $hs1vm1Endpoints -usage udp
    $dtapServerUdpport = "990"
    $hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh	
    $dtapServerSshport = "22"
    $dtapServerIp = $xmlConfig.config.Azure.Deployment.Data.DTAP.IP
    $testPort = $hs1vm1tcpport + 10
    foreach ($mode in $currentTestData.TestMode.Split(","))
    {
        try
        {
            $testResult = $null
	        $cmd1="./start-server.py -p $testPort -u yes&& mv Runtime.log start-server.py.log"
            if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
            {
    	        $cmd2="./start-client.py -c $hs1VIP -p $testPort -t10 -u yes -l 1420"
	        }

            if(($mode -eq "URL") -or ($mode -eq "Hostname"))
            {
	            $cmd2="./start-client.py -c $hs1ServiceUrl -p $testPort -t10 -u yes -l 1420"
	        }

	        $a = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodetcpPort $hs1vm1tcpport
	        $b = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodetcpPort $dtapServerTcpport
            mkdir $LogDir\$mode -ErrorAction SilentlyContinue | out-null
            $b.logDir = $LogDir + "\$mode"
	        $a.logDir = $LogDir + "\$mode"
	        $server = $a
	        $client = $b
            $testResult = IperfClientServerUDPNonConnectivity -server $server -client $client
            LogMsg "$($currentTestData.testName) : $mode : $testResult"
        }
        catch
        {
            $ErrorMessage =  $_.Exception.Message
            LogMsg "EXCEPTION : $ErrorMessage"   
        }
        Finally
        {
            $metaData = $mode 
            if (!$testResult)
            {
                $testResult = "Aborted"
            }
            $resultArr += $testResult
            $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
       }
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
return $result,$resultSummary