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
        $hs1vm1Hostname =  $hs1vm1.Name


        RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
        RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo


        LogMsg "Executing : $($currentTestData.testScript)"
        $output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python ./$($currentTestData.testScript) -e $hs1vm1Hostname" -runAsSudo
        $testResult = "PASS"
        
        LogMsg "Test result : $testResult"

        LogMsg "Stopping prepared OS image : $hs1vm1Hostname"
        $tmp = Stop-AzureVM -ServiceName $isDeployed -Name $hs1vm1Hostname -Force
        LogMsg "Stopped the VM succussfully"
        
        LogMsg "Capturing the OS Image"
        $NewImageName = $isDeployed + '-prepared'
        $tmp = Save-AzureVMImage -ServiceName $isDeployed -Name $hs1vm1Hostname -NewImageName $NewImageName -NewImageLabel $NewImageName
        LogMsg "Successfully captured VM image : $NewImageName"
        
        # Capture the prepared image names
        $PreparedImageInfoLogPath = "$pwd\PreparedImageInfoLog.xml"
        if((Test-Path $PreparedImageInfoLogPath) -eq $False)
        {
            $PreparedImageInfoLog = New-Object -TypeName xml
            $root = $PreparedImageInfoLog.CreateElement("PreparedImages")
            $content = "<PreparedImageName></PreparedImageName>"
            $root.set_InnerXML($content)
            $PreparedImageInfoLog.AppendChild($root)
            $PreparedImageInfoLog.Save($PreparedImageInfoLogPath)
        }
        [xml]$xml = Get-Content $PreparedImageInfoLogPath
        $xml.PreparedImages.PreparedImageName = $NewImageName
        $xml.Save($PreparedImageInfoLogPath)
        
        
        if ($testStatus -eq "TestCompleted")
        {
            LogMsg "Test Completed"
        }
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
        # Remove the Cloud Service
        LogMsg "Executing: Remove-AzureService -ServiceName $isDeployed -Force"
        Remove-AzureService -ServiceName $isDeployed -Force
    }
}
else
{
    $testResult = "Aborted"
    $resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result