Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

try
{
    $isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
    if ($isDeployed)
    {
        foreach ($VM in $allVMData)
            {
                $ResourceGroupUnderTest = $VM.ResourceGroupName
                $diskName = "disk01"
                $diskSizeinGB = "10"
                $VirtualMachine = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.RoleName
                $VHDuri = $VirtualMachine.StorageProfile.OsDisk.Vhd.Uri
                $VHDUri = $VHDUri.Replace("osdisk","datadisk")
                LogMsg "Adding an empty data disk to the resource group"
                $out = Add-AzureRMVMDataDisk -VM $VirtualMachine -Name $diskName -DiskSizeInGB $diskSizeinGB -LUN 0 -VhdUri $VHDuri.ToString() -CreateOption Empty
		        LogMsg "Successfully created an empty data disk"
		        
                $out = Update-AzureRMVM -VM $VirtualMachine -ResourceGroupName $ResourceGroupUnderTest
                LogMsg "Successfully added an empty data disk to the resource group"
                LogMsg "Verifying if data disk is added to the VM: Running fdisk on remote VM"
                $fdiskOutput = RunLinuxCmd -username $user -password $password -ip $VM.PublicIP -port $VM.SSHPort -command "/sbin/fdisk -l | grep /dev/sdc" -runAsSudo
                if($fdiskOutput -imatch "/dev/sdc" -and (($fdiskOutput.Split()[2]) -ge $diskSizeinGB))
                {
                    LogMsg "Data disk is successfully added to the VM"
                    #$testResult = "PASS"
                }
                else 
                {
                    LogMsg "Data disk is NOT added to the VM"
                    Break
                    #$testResult = "FAIL"
                }

                LogMsg "Removing the data disk from the VM"
                $out = Remove-AzureRmVMDataDisk -VM $VirtualMachine -DataDiskNames $diskName
                $out = Update-AzureRMVM -VM $VirtualMachine -ResourceGroupName $ResourceGroupUnderTest
                #LogMsg "Successfully removed the data disk from the VM"
                LogMsg "Verifying if data disk is removed from the VM: Running fdisk on remote VM"

                $fdiskOutput = RunLinuxCmd -username $user -password $password -ip $VM.PublicIP -port $VM.SSHPort -command "/sbin/fdisk -l | grep /dev/sdc" -runAsSudo -ignoreLinuxExitCode
                if($fdiskOutput -imatch "/dev/sdc")
                {
                    LogMsg "Data disk is NOT removed from the VM"
                    $testResult = "FAIL"
                }
                else 
                {
                    LogMsg "Data disk is successfully removed from the VM"
                    $testResult = "PASS"
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
        }
        $resultArr += $testResult
    }   
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
