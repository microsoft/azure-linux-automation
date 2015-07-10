<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

#Define Lun arrays according to VM size.
$ExtraSmallVMLUNs = 0
$SmallVMLUNs = 0..1
$MediumVMLUNs = 0..3
$LargeVMLUNs = 0..7
$ExtraLargeVMLUNs= 0..15
$DS1LUNs = 0..1
$DS2LUNs = 0..3
$DS3LUNs = 0..7
$DS4LUNs= 0..15

$diskResult = New-Object -TypeName System.Object
foreach ($newSetupType in $currentTestData.SubtestValues.split(","))
{
    #Deploy A new VM..
    LogMsg "Test started for : $newSetupType."
    $isDeployed = DeployVMS -setupType $newSetupType -Distro $Distro -xmlConfig $xmlConfig
    <#
    Use following deployment for debuggging purpose. You need to comment out upper line in this case.
    #>
    #$isDeployed = "ICA-DS1NODISK-S11SP3BPXSA-6-29-6-19-55" #Debug Code                

    #Start Test if Deployment is successfull.
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

        mkdir "$LogDir\$newSetupType"
        $testVMObject = CreateHotAddRemoveDataDiskNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -ServiceName $isDeployed -logDir "$LogDir\$newSetupType"
        RemoteCopy -uploadTo $testVMObject.ip -port $testVMObject.sshPort -files $currentTestData.files -username $testVMObject.user -password $testVMObject.password -upload
        $suppressedout = RunLinuxCmd -ip $testVMObject.ip  -port $testVMObject.sshPort  -username $testVMObject.user  -password $testVMObject.password  -command "chmod +x *.sh" -runAsSudo
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

        $HotAddDiskCommand = "DoHotAddNewDataDiskTest -testVMObject `$testVMObject -diskSizeInGB `$diskSize"
        $HotRemoveDiskCommand = "DoHotRemoveDataDiskTest -testVMObject `$testVMObject"

        foreach ($newTask in $testTasks)
        {
            if ($newTask -eq "Remove")
            {
                [Array]::Reverse($testLUNs)
            }
            foreach ($newLUN in $testLUNs)
            {
                try
                {
                    $testVMObject.Lun = $newLUN
                    $LunString = "LUN$newLUN"
                    $testResult = ""
                    Add-Member -InputObject $diskResult.$newSetupType -MemberType MemberSet -Name $LunString -ErrorAction SilentlyContinue
                    if ($newTask -eq "Add")
                    {
                        $testCommand = $HotAddDiskCommand
                        $diskSize = (($newLUN + 1)*10)
                        $metaData = "$newSetupType : Add : LUN$newLUN : $diskSize.0GB"
                    }
                    elseif ($newTask -eq "Remove")
                    {
                        $testCommand = $HotRemoveDiskCommand
                        $diskSize = (($newLUN + 1)*10)
                        $metaData = "$newSetupType : Remove : LUN$newLUN"
                    }

                    #Execute Test Here
                    if ($newTask -eq "Remove")
                    {
                        if($diskResult.$newSetupType.$LunString.Add -eq "PASS")
                        {
                            $testResult = Invoke-Expression $testCommand
                        }
                        else
                        {
                            LogErr "Not executing remove disk test because Add Disk test was $($diskResult.$newSetupType.$LunString.Add)."
                            $testResult = "FAIL"
                        }
                    }
                    else
                    {
                        $testResult = Invoke-Expression $testCommand
                    }
                    
                    Add-Member -InputObject $diskResult.$newSetupType.$LunString -NotePropertyName $newTask -NotePropertyValue $testResult
                    LogMsg "$($currentTestData.TestName) : $newSetupType : $newTask : $diskSize.0GB: $testResult"
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

$result = GetFinalResultHeader -resultarr $resultArr

#Return the result and summery to the test suite script..
return $result, $resultSummary 