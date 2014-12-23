#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
# Author - v-shisav@microsoft.com
#####################################################################
<#
.Synopsis
This code checks the disk performance by "fio" tool
.Description
This code checks the disk performance by "fio" tool
Currently tested OS platforms:
Ubuntu 14.10
OpenSuse 13.1
Required Packages :
+fio
+libaio1
.Link
None.
#>

Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

#Deploy A new VM..
$isDeployed = DeployVMS -setupType $currentTestData.setupType  -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
    try
    {
        Function RemoveAllAlphabetsAndCharacters($inputString)
        {
            $charactersToRemove = ('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',`
            'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',`
            '!','@','#','$','%','^','&','*','(',')','[',']','{','}',':','"',"'",';',',','.','/',' ')
            foreach ( $character in $charactersToRemove )
            {
                $inputString = $inputString.Replace($character,"")
            }
            return $inputString
        }

        #region COLLECTE DEPLOYED VM DATA
        $testServiceData = RetryOperation -operation { Get-AzureService -ServiceName $isDeployed } -description "Getting service details..." -maxRetryCount 10 -retryInterval 5
        #Get VMs deployed in the service..
        $testVMsinService = RetryOperation -operation { $testServiceData | Get-AzureVM } -description "Getting VM details..." -maxRetryCount 10 -retryInterval 5
        $hs1vm1 = $testVMsinService
        $hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
        $hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
        $hs1VIP = $hs1vm1Endpoints[0].Vip
        $hs1ServiceUrl = $hs1vm1.DNSName
        $hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
        $hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
        #endregion

        $detectedDistro = DetectLinuxDistro -VIP $hs1VIP -SSHport $hs1vm1sshport -testVMUser $user -testVMPassword $password

        #Get the resource disk path and get the resourc disk size .
        $mountOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mount | grep sdb1"
    
        LogMsg "Detecting resource disk..."

        if ( $mountOut -imatch "/dev/sdb1 on /mnt/resource")
        {
            $resourceDiskPath = "/mnt/resource"
            LogMsg "Detected resource disk at /mnt/resource"
        }
        elseif ( $mountOut -imatch "/dev/sdb1 on /mnt")
        {
            $resourceDiskPath = "/mnt"
            LogMsg "Detected resource disk at /mnt"
        }
        else
        {
            LogErr $mountOut
            Throw "Unable to detect the resource disk in VM."
        }
        
        #Upload files to test VM..
        RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -username $user -password $password -files $currentTestData.files -upload
        RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *.py *.sh"
        
        #Install Required Packages..
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./packageInstall.sh -install UpdateCurrentDistro" -runAsSudo -runMaxAllowedTime 1200
        LogMsg "Updated Current Distro."
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./packageInstall.sh -install fio -isLocal no" -runAsSudo
        LogMsg "Installed Fio."
        $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "./packageInstall.sh -install libaio1 -isLocal no" -runAsSudo
        LogMsg "Installed libaio1."
        
        #Get the resource disk size and make sure that test file size is less than disk size or abort the test
        if ( $detectedDistro -eq "SUSE" )
        {
            $resourceDiskSizeKb = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/usr/sbin/fdisk -l | awk '/sdb/ { print `$5}' | awk 'NR==1'" -runAsSudo
        }
        else
        {
            $resourceDiskSizeKb = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "fdisk -l | awk '/sdb/ { print `$5}' | awk 'NR==1'" -runAsSudo
        }
        $resourceDiskSizeKb = RemoveAllAlphabetsAndCharacters -inputString $resourceDiskSizeKb
        if ( ($currentTestData.TestFileSizeinGB) -gt ($resourceDiskSizeKb/1024/1024/1024))
        { 
            Throw "Test file size mentioned in XML file is greater than resource disk."
        }
        else
        {
            LogMsg "Resource disk size is $($resourceDiskSizeKb/1024/1024/1024)GB. Test file is $($currentTestData.TestFileSizeinGB)GB. Continuing test..."
        }

        $azureFioConfigFile = Get-Content .\remote-scripts\azure-ssd-test.fio
        
        #Actual Test Starts here..
        foreach ( $iosize in $currentTestData.ioSizes.split(","))
        {
            foreach ( $queDepth in $currentTestData.queueDepths.split(","))
            {
                try 
                {
                    $metaData = "$iosize : $queDepth"
                    $aioConfigFileString = ""

                    #Generate the fio configuration file
                    foreach ( $line in $azureFioConfigFile )
                    {
                        $aioConfigFileString += ( $line + "`n" )
                    }
                    $aioConfigFileString = $aioConfigFileString.Replace("io_size",$iosize + "k")
                    if ($currentTestData.ioengine)
                    {
                        $aioConfigFileString = $aioConfigFileString.Replace("io_engine",$currentTestData.ioengine )
                    }
                    else
                    {
                        $aioConfigFileString = $aioConfigFileString.Replace("io_engine","libaio")
                    }
                    $aioConfigFileString = $aioConfigFileString.Replace("queue_depth",$queDepth)
                    $aioConfigFileString = $aioConfigFileString.Replace("file_size",$currentTestData.TestFileSizeinGB + "g")
                    $aioConfigFileString = $aioConfigFileString.Replace("run_time",$currentTestData.runtimeSeconds)
                    $aioConfigFileString = $aioConfigFileString.Replace("resource_disk_path",$resourceDiskPath)
                    Set-Content -Value $aioConfigFileString -Path ".\$LogDir\fio-$iosize-$queDepth.aio"
                    RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -username $user -password $password -files ".\$LogDir\fio-$iosize-$queDepth.aio" -upload
                    $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python start-fio.py -f fio-$iosize-$queDepth.aio" -runAsSudo
                    WaitFor -seconds 10
                    $isFioStarted  = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat FioConsoleOutput.log" ) -imatch "Starting \d processes")
                    if ( $isFioStarted )
                    { 
                        LogMsg "Fio Test Started successfully for iosize : ${iosize}k, queueDepth : $queDepth, FileSize : $($currentTestData.TestFileSizeinGB)GB and Runtime = $($currentTestData.runtimeSeconds) seconds.."
                        WaitFor -seconds 60 
                    }
                    else
                    {
                        Throw "Failed to start fio tests."
                    }
                    $isFioFinished = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat FioConsoleOutput.log" ) -imatch " merge=")
                    while (!($isFioFinished))
                    {
                        LogMsg "Fio Test is still running for iosize : ${iosize}k, queueDepth : $queDepth, FileSize : $($currentTestData.TestFileSizeinGB)GB.. Please wait.."
                        $isFioFinished = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat FioConsoleOutput.log" ) -imatch " merge=")
                        WaitFor -seconds 15
                    }
                    LogMsg "Great! Fio test is finished now."
                    RemoteCopy -downloadFrom $hs1VIP -port $hs1vm1sshport -username $user -password $password -files "FioConsoleOutput.log" -downloadTo $LogDir -download
                    Rename-Item -Path "$LogDir\FioConsoleOutput.log" -NewName "FIOLOG-${iosize}k-$queDepth.log" -Force | Out-Null
                    LogMsg "Fio Logs saved at :  $LogDir\FIOLOG-${iosize}k-$queDepth.log"
                    LogMsg "Removing all log files from test VM."
                    $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -rf *.log" -runAsSudo
                    $testResult = "PASS"
                }
                catch
                {
                    $ErrorMessage =  $_.Exception.Message
                    LogMsg "EXCEPTION : $ErrorMessage"   
                }
                finally
                {
                    if (!$testResult)
                    {
                        $testResult = "Aborted"
                    }
                    $resultArr += $testResult
                    $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
                }
            }
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
            $resultArr += $testResult
            $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
        }
    }
}
else
{
    $testResult = "Aborted"
    $resultArr += $testResult
    $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result, $resultSummary 