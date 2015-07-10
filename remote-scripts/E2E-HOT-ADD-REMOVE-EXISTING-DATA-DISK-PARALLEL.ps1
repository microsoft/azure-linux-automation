<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

#Define Lun arrays according to VM size.
$ExtraSmallVMLUNs = 1
$SmallVMLUNs = 2
$MediumVMLUNs = 4
$LargeVMLUNs = 8
$ExtraLargeVMLUNs= 16
$DS1LUNs = 2
$DS2LUNs = 4
$DS3LUNs = 8
$DS4LUNs= 16

$diskResult = New-Object -TypeName System.Object
#Get Medial Links of existing disks from XML file.
$ExistingDisks = @()
foreach ($newDisk in $currentTestData.ExistingDisks.MediaLink)
    {
        $ExistingDisks += $newDisk
    }
LogMsg "Collected $($ExistingDisks.Length) Existing disks."
foreach ($newSetupType in $currentTestData.SubtestValues.split(","))
{
    #Deploy A new VM..
    LogMsg "Test started for : $newSetupType."
    $isAllDisksAvailable = CleanUpExistingDiskReferences -ExistingDiskMediaLinks $ExistingDisks
    if ($isAllDisksAvailable)
    {
        $isDeployed = DeployVMS -setupType $newSetupType -Distro $Distro -xmlConfig $xmlConfig
        if ($isDeployed)
        {
    #region COLLECTE DEPLOYED VM DATA
            $testServiceData = Get-AzureService -ServiceName $isDeployed
            Add-Member -InputObject $diskResult -MemberType MemberSet -Name $newSetupType
            #Get VMs deployed in the service..
            $testVMsinService = $testServiceData | Get-AzureVM

            $hs1vm1 = $testVMsinService
            $hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
            $hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
            $hs1VIP = $hs1vm1Endpoints[0].Vip
            $hs1ServiceUrl = $hs1vm1.DNSName
            $hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
            $hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
    #endregion

            mkdir "$LogDir\$newSetupType" | Out-Null
            $testVMObject = CreateHotAddRemoveDataDiskNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -ServiceName $isDeployed -logDir "$LogDir\$newSetupType" -allExistingDisks $ExistingDisks
        
            <#This script doesn't need any file to upload, however, we need to upload at least one file to New deployment in order to cache the key to our server. 
            RemoteCypy function is written to cache the server key. So that RunLinuxCmd function can work well..#>
            RemoteCopy -uploadTo $testVMObject.ip -port $testVMObject.sshPort -files $currentTestData.files -username $testVMObject.user -password $testVMObject.password -upload
        
            switch ($hs1vm1.InstanceSize)
            {
                "ExtraSmall"
                {
                    $testLUNs = $ExtraSmallVMLUNs
                }
                "Small"
                {
                    $testLUNs = $SmallVMLUNs
                }
                "Medium"
                {
                    $testLUNs = $MediumVMLUNs
                }
                "Large"
                {
                    $testLUNs = $LargeVMLUNs
                }
                "ExtraLarge"
                {
                    $testLUNs = $ExtraLargeVMLUNs
                }
                "Standard_DS1"
                {
                    $testLUNs = $DS1LUNs
                }
                "Standard_DS2"
                {
                    $testLUNs = $DS2LUNs
                }
                "Standard_DS3"
                {
                    $testLUNs = $DS3LUNs
                }
                "Standard_DS4"
                {
                    $testLUNs = $DS4LUNs
                }
            }

    #region HOT ADD / REMOVE DISKS..
            $testTasks = ("Add","Remove")

            $HotAddDiskParallelCommand = "DoHotAddExistingDataDiskTestParallel -testVMObject `$testVMObject -TotalLuns `$testLUNs"
            $HotRemoveDiskParallelCommand = "DoHotRemoveNewDataDiskTestParallel -testVMObject `$testVMObject -TotalLuns `$testLUNs"

            foreach ($newTask in $testTasks)
            {
                try
                {
                    if ($newTask -eq "Add")
                    {
                        $testCommand = $HotAddDiskParallelCommand
                        $metaData = "$newSetupType : Add : Disks : $testLUNs"
                    }
                    elseif ($newTask -eq "Remove")
                    {
                        $testCommand = $HotRemoveDiskParallelCommand
                        $metaData = "$newSetupType : Remove : Disks : $testLUNs"
                    }

                    #Execute Test Here
                    if ($newTask -eq "Remove")
                    {
                        if($diskResult.$newSetupType.Add -eq "PASS")
                        {
                            $testResult = Invoke-Expression $testCommand
                        }
                        else
                        {
                            LogErr "Not executing remove disk test because Add Disk test was $($diskResult.$newSetupType.Add)."
                            $testResult = "FAIL"
                        }
                    }
                    else
                    {
                        $testResult = Invoke-Expression $testCommand
                    }
                    Add-Member -InputObject $diskResult.$newSetupType -NotePropertyName $newTask -NotePropertyValue $testResult
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
                    $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
                }
            }
    #endregion
            $result = GetFinalResultHeader -resultarr $resultArr   
            DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed
        }

        else
        {
            $testResult = "Aborted"
            $resultArr += $testResult
            $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
        }
    }
    else
    {
        LogErr "Some Existing Disks are not available for tests. Aborting test."
        $testResult = "Aborted"
        $resultArr += $testResult
        $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
    }
}

$result = GetFinalResultHeader -resultarr $resultArr

#Return the result and summery to the test suite script..
return $result, $resultSummary 