<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$AccessKey=$currentTestData.AccessKey
$AzureShare=$currentTestData.AzureShareUrl
$MountPoint=$currentTestData.MountPoint

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

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
        
		LogMsg "Executing : $($currentTestData.testScript)"
		$out=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python $($currentTestData.testScript) -p $AccessKey -s $AzureShare -m $MountPoint" -runAsSudo -runmaxallowedtime 3600 -ignoreLinuxExitCode 
		WaitFor -seconds 60
		$TStatus=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat xfstest.log" -runAsSudo -ignoreLinuxExitCode
		if(!$TStatus -imatch "FSTYP.*cifs")
		{
			$total_time = 0
			$interval = 600
			WaitFor -seconds 60
			while($true)
			{	
				$xStatus=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/xfstests/results/check.log " -runAsSudo -ignoreLinuxExitCode
				$checkStatus=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "pgrep check|wc -l" -runAsSudo -ignoreLinuxExitCode
				if($xStatus -imatch "Failed.*of.*tests")
				{
					$testResult = "PASS"
					LogMsg "$($currentTestData.testScript) Completed.. "
					break
				}elseif(!$checkStatus)
				{
					$testResult = "FAIL"
					LogMsg "$($currentTestData.testScript) Completed.. "
					break   
				}

				if ($total_time -gt 720000)
				{
					$testResult = "FAIL"
					LogMsg "$($currentTestData.testScript) is taking more than 20 hrs this is bad.. "
					break					
				}
				WaitFor -seconds $interval
				$total_time += $interval
			}
		}
		else
		{
			$testResult = "Failed"
			LogMsg "xfstests not started.. "
			LogMsg "Error: $TStatus"
			$testResult = "PASS"
		}
		if($testResult -eq "PASS")
		{
			$out=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/bin/bash GetXsmbXfsTestStatus.sh" -runAsSudo -ignoreLinuxExitCode
			LogMsg "Xfs Test Status : $out"
		}
		$out=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -cvzf xfstestfull.tar.gz /home/$user/ " -runAsSudo
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/xfstest.log, /home/$user/xfstestfull.tar.gz" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
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
