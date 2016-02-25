<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()


Function RetryStartTest($vmuser, $vmpassword, $vmvip, $vmport)
{
  $out = '0'
  while ($out -ne '1')
  {
    RunLinuxCmd -username $vmuser -password $vmpassword -ip $vmvip -port $vmport -command "$python_cmd $($currentTestData.entrytestScript) -d $($currentTestData.parameters.duration) -p $($currentTestData.parameters.pkg) -t $($currentTestData.parameters.timeout) -s" -runAsSudo
    sleep 5
    $out = RunLinuxCmd -username $vmuser -password $vmpassword -ip $vmvip -port $vmport -command "cat Runtime.log | grep -i 'red hat' | wc -l"
  }
}

Function WaitForRHUIInstall($vmuser, $vmpassword, $vmvip, $vmport)
{
  $out = '0'
  while ($out -ne '1')
  {
    sleep 10
    $out = RunLinuxCmd -username $vmuser -password $vmpassword -ip $vmvip -port $vmport -command "cat /var/log/waagent.log | grep -i 'install RHUI RPM completed' | wc -l"
  }
}


if ( $UseAzureResourceManager )
{
    $VMRegion = ($currentTestData.ARMRegion).Split(",")
    $VMStorageAccount = ($currentTestData.ARMStorageAccount).Split(",")
}
else
{
    $VMRegion = ($currentTestData.ASMRegion).Split(",")
    $VMStorageAccount = ($currentTestData.ASMStorageAccount).Split(",")
}
$index = $VMRegion.Count
#Test Starts Here..
while($index -gt 0)
{   
    $isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig  -region $VMRegion[$index-1] -storageAccount $VMStorageAccount[$index-1]
    
    if($isDeployed)
    {
       try
       {
        $hs1VIP = $AllVMData.PublicIP
        $hs1ServiceUrl = $AllVMData.URL
        $hs1vm1IP = $AllVMData.InternalIP
        $hs1vm1Hostname = $AllVMData.RoleName
        $hs1vm1sshport = $AllVMData.SSHPort
        $hs1vm1tcpport = $AllVMData.TCPtestPort
        $hs1vm1udpport = $AllVMData.UDPtestPort
   
        $DistroName = DetectLinuxDistro -VIP $hs1VIP -SSHport $hs1vm1sshport -testVMUser $user -testVMPassword $password
        if ($DistroName -eq "REDHAT")
        {
          
          WaitForRHUIInstall -vmuser $user -vmpassword $password -vmvip $hs1VIP -vmport $hs1vm1sshport
          RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
          RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
          if($currentTestData.RunDownload)
          {
            RetryStartTest -vmuser $user -vmpassword $password -vmvip $hs1VIP -vmport $hs1vm1sshport
            sleep $currentTestData.parameters.duration
            sleep 20
            RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Runtime.log $($currentTestData.downloadtestScript).log" -runAsSudo
            RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/$($currentTestData.downloadtestScript).log" -downloadTo $LogDir\$hs1vm1Hostname -port $hs1vm1sshport -username $user -password $password
          }

          
          LogMsg "Executing : $($currentTestData.testScript)"
          RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "$python_cmd $($currentTestData.testScript)" -runAsSudo
          RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Runtime.log $($currentTestData.testScript).log" -runAsSudo
          RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/state.txt, /home/$user/Summary.log, /home/$user/$($currentTestData.testScript).log" -downloadTo $LogDir\$hs1vm1Hostname -port $hs1vm1sshport -username $user -password $password
          $testResult = Get-Content $LogDir\$hs1vm1Hostname\Summary.log
          $testStatus = Get-Content $LogDir\$hs1vm1Hostname\state.txt
          LogMsg "Test result : $testResult"
        }
        else
        {
          LogMsg "The Distro is not Redhat, skip the test!"
          $testResult = 'PASS'
          $testStatus = 'TestCompleted'
          break;
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
          $index = $index - 1;
       }
    }
    else
    {
       $testResult = "Aborted"
       $resultArr += $testResult
    }
    $result = GetFinalResultHeader -resultarr $resultArr
    DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed
}

return $result

