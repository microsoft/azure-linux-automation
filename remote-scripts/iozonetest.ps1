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
$hs1Name = "ICA-LargeVM-Ubuntu1310Daily-7-10-4-33-54"
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
$dtapServerIp="131.107.220.167"

$cmd1="./start-iozone.py -r4k -s1m -k8"
$cmd2="./start-client.py -c $dtapServerIp -i1 -p $dtapServerTcpport -t20"
$iozoneNode=CreateIozoneNode -fileSize "64" -recordSize "4K" -logDir $LogDir -storageType "XStore"
$iozoneNode.diskDetails="Root Disk"
$iozoneNode.files=$currentTestData.files
$iozoneNode.user=$user
$iozoneNode.sshPort=$hs1vm1sshport
$iozoneNode.password=$password
$iozoneNode.ip=$hs1VIP

$currentTestData = GetCurrentTestData -xmlConfig $xmlConfig -testName $test.Name
$lisBuild = $xmlConfig.config.global.VMEnv.LISBuild
$lisBuildBranch = $xmlConfig.config.global.VMEnv.LISBuildBranch
$VMImageDetails = $xmlConfig.config.global.VMEnv.VMImageDetails
	

#region Test Steps Execution
#RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "apt-get -y install dos2unix" -runAsSudo
RemoteCopy -uploadTo $iozoneNode.ip -port $iozoneNode.sshPort -files $iozoneNode.files -username $iozoneNode.user -password $iozoneNode.password -upload
RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "chmod +x *" -runAsSudo
RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "echo TestStarted > iozone.txt" -runAsSudo
$startTime = [Datetime]::Now
RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command $cmd1 -runAsSudo
RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "dos2unix geniozoneresults.sh" -runAsSudo
RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "./geniozoneresults.sh iozone.txt" -runAsSudo
$endTime = [Datetime]::Now
$runDuration = $endTime - $startTime
$runDuration=$runDuration.TotalMinutes
$testCaseRunObj.startTime= $startTime
$testCaseRunObj.endTime = $endTime
#UpdateTestRunDuration -conn $conn -testRunObj $testRunObj
RemoteCopy -download -downloadFrom $iozoneNode.ip -files "/home/test/iozoneformatted.txt" -downloadTo $iozoneNode.LogDir -port $iozoneNode.sshPort -username $iozoneNode.user -password $iozoneNode.password
RemoteCopy -download -downloadFrom $iozoneNode.ip -files "/home/test/iozone.txt" -downloadTo $iozoneNode.LogDir -port $iozoneNode.sshPort -username $iozoneNode.user -password $iozoneNode.password

#endregion

#region Iozone Results Collection

$iozoneNode.diskDetails ="RootDisk"
$logFile=$iozoneNode.logDir + "\iozoneformatted.txt"
$iozoneResult=GetIozoneResultAllValues $logFile
$iozoneNode.write=$iozoneResult.write
$iozoneNode.rewrite=$iozoneResult.rewrite
$iozoneNode.read=$iozoneResult.read
$iozoneNode.reread = $iozoneResult.reread
$iozoneNode.randomread=$iozoneResult.randread
$iozoneNode.randomwrite=$iozoneResult.randwrite
$iozoneNode.bkwdread=$iozoneResult.bkwdread
$iozoneNode.recordrewrite=$iozoneResult.recrewrite
$iozoneNode.strideread=$iozoneResult.strideread

#endregion

#region Database Method
#$conn=ConnectSqlDB -sqlServer "LISINTER620-4" -sqlDBName "LISPerfTestDB"
#$id=GenerateTestRunID -conn $conn
$now = [Datetime]::Now.ToString("MM/dd/yyyy hh:mm:ss")
$depId= GetDeploymentId $hs1Name
Write-Host $depId
$kernelVersion=RunLinuxCmd -username $iozoneNode.user -password $iozoneNode.password -ip $iozoneNode.ip -port $iozoneNode.sshPort -command "uname -r" -runAsSudo
$waagentBuild=""
$vmRam= "2048"
$vmVcpu = "3"
#$vmEnvObj= CreateVMEnvObject -lisBuildBranch "Released" -lisBuild "3.1" -kernelVersion "3.1.9" -waagentBuild "1024" -vmRam "2048" -vmVcpu "2"
$testCaseRunObj.vmRam=$vmRam
$testCaseRunObj.vmVcpu=$vmVcpu

$vmEnvObj= CreateVMEnvObject -lisBuildBranch $lisBuildBranch -lisBuild $lisBuild -kernelVersion $kernelVersion -waagentBuild $waagentBuild -vmImageDetails $VMImageDetails
Write-Host $vmEnvObj
Set-Variable -Name vmEnvObj -Value $vmEnvObj -Scope Global
$testCaseRunObj.deploymentId = $depId
#$testRunDisk = CreateTestRunObject -testRunId $testRunObj.id -runDate $now -server $server -testName "Test Case Iozone" -testDescp $testDescription -testCategory "DiskPerf" -testId "DiskIozone" -linuxDistro "Ubuntu" -perfTool "Iozone" 
#$testRunDisk.testRunDuration=$runDuration
#$testRunDisk.comments="Disk Test for Prototype"
#$tmp=AddTestDetailsinDB -conn $conn -testCaseObj $testRunDisk
$testCaseRunObj.result="Pass"
AddTestCaseDetailsinDB -conn $conn -testCaseObj $testCaseRunObj -testSuiteRunId $testSuiteRunObj.testSuiteRunId
$tmp=AddIozoneResultsinDB -conn $conn -iozoneObj $iozoneNode -testCaseObj $testCaseRunObj -testSuiteRunId $testSuiteRunObj.testSuiteRunId
#AddClusterEnvDetailsinDB -conn $conn -clusterObj $clusterObj -testRunId $id



#endregion
$iozoneHeader="DiskTest Results:"
$result = $iozoneHeader  + " <br />"
$result += "		" + "fileSize" + " :" + $iozoneNode.fileSize + " <br />"
$result += "		" + "recordSize" + " :" + $iozoneNode.recordSize + " <br />"
foreach ($key in @($iozoneResult.Keys))
{
	$result += "		" + $key + " :" + $iozoneResult[$key] + " <br />"
}
return $result


