#region Import Modules

Import-Module .\TestLibs\RDFELibs.psm1 -Force 
Import-Module .\TestLibs\DataBase\DataBase.psm1 -Force
Import-Module .\TestLibs\PerfTest\PerfTest.psm1 -Force
Get-Command -Module .\TestLibs\PerfTest\PerfTest.psm1
Get-Command -Module .\TestLibs\DataBase\DataBase.psm1
#Import-Module -Name Database -Force
#Import-Module -Name PerfTest -Force
#Get-Command -Module PerfTest
##Get-Command -Module Database

#endregion

#$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

#LogMsg "Skipping Deployment..."

if ($isDeployed -eq "False")
{
    exit
}

#$hs1Name = $isDeployed
$hs1Name = "ICA-PublicEndpoint-VjUbuntuLTS-6-3-2013-17-28"
$testServiceData = Get-AzureService -ServiceName $hs1Name

#Get VMs deployed in the service..
$testVMsinService = $testServiceData | Get-AzureVM

$hs1vm1 = $testVMsinService
$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint

$hs1VIP = $hs1vm1Endpoints[0].Vip
$hs1ServiceUrl = $hs1vm1.DNSName
$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")


	
#$hs1vm2 = $testVMsinService[1]
#$hs1vm2Endpoints = $hs1vm2 | Get-AzureEndpoint
$hs1vm1tcpport = GetPort -Endpoints $hs1vm1Endpoints -usage tcp
$dtapServerTcpport = "750"
$hs1vm1udpport = GetPort -Endpoints $hs1vm1Endpoints -usage udp
$dtapServerUdpport = "990"
$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh	
$dtapServerSshport = "22"
#$dtapServerIp="131.107.220.167"

$cmd1 = "./start-server.py -p $hs1vm1tcpport && mv Runtime.log start-server.py.log"
$cmd2="./start-client.py -c $hs1VIP -p $hs1vm1tcpport -t10"
$server = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
$client = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir

#region Test Steps Execution


$startTime = [Datetime]::Now
$bandwidth=IperfClientServerPerfTest -server $server -client $client
$endTime = [Datetime]::Now
$runDuration = $endTime - $startTime
$runDuration=$runDuration.TotalMinutes
$testCaseRunObj.startTime= $startTime
$testCaseRunObj.endTime = $endTime


#endregion

#region Iozone Results Collection

#$iozoneNode.diskDetails ="RootDisk"
#$logFile=$iozoneNode.logDir + "\iozoneformatted.txt"
#$iozoneResult=GetIozoneResultAllValues $logFile
#$iozoneNode.write=$iozoneResult.write
#$iozoneNode.rewrite=$iozoneResult.rewrite
#$iozoneNode.read=$iozoneResult.read
#$iozoneNode.reread = $iozoneResult.reread
#$iozoneNode.randomread=$iozoneResult.randread
#$iozoneNode.randomwrite=$iozoneResult.randwrite
#$iozoneNode.bkwdread=$iozoneResult.bkwdread
#$iozoneNode.recordrewrite=$iozoneResult.recrewrite
#$iozoneNode.strideread=$iozoneResult.strideread

#endregion

#region Database Method
#$conn=ConnectSqlDB -sqlServer "LISINTER620-4" -sqlDBName "LISPerfTestDB"
#$id=GenerateTestRunID -conn $conn
$now = [Datetime]::Now.ToString("MM/dd/yyyy hh:mm:ss")
$depId= GetDeploymentId $hs1Name
#$kernelVersion=RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "uname -r" -runAsSudo

$vmRam= "2048"
$vmVcpu = "3"
#$vmEnvObj= CreateVMEnvObject -lisBuildBranch "Released" -lisBuild "3.1" -kernelVersion "3.1.9" -waagentBuild "1024" -vmRam "2048" -vmVcpu "2"
$testCaseRunObj.vmRam=$vmRam
$testCaseRunObj.vmVcpu=$vmVcpu

$testCaseRunObj.deploymentId = GetDeploymentId $hs1Name
#$testRunDisk = CreateTestRunObject -testRunId $testRunObj.id -runDate $now -server $server -testName "Test Case Iozone" -testDescp $testDescription -testCategory "DiskPerf" -testId "DiskIozone" -linuxDistro "Ubuntu" -perfTool "Iozone" 
#$testRunDisk.testRunDuration=$runDuration
#$testRunDisk.comments="Disk Test for Prototype"
#$tmp=AddTestDetailsinDB -conn $conn -testCaseObj $testRunDisk
$testCaseRunObj.result="Pass"
Write-Host $testCaseRunObj
AddTestCaseDetailsinDB -conn $conn -testCaseObj $testCaseRunObj -testSuiteRunId $testSuiteRunObj.testSuiteRunId
$tmp=AddIPerfResultsinDB -conn $conn -bandwidth $bandwidth -testCaseObj $testCaseRunObj -testSuiteRunId $testSuiteRunObj.testSuiteRunId
#AddClusterEnvDetailsinDB -conn $conn -clusterObj $clusterObj -testRunId $id



#endregion

return $bandwidth


