<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$constFile = "constants.sh"
$KernelVersion=""
$NewKernelVersion=""

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

		if (test-path $constFile)
		{
			del $constFile -ErrorAction "SilentlyContinue"
		}
		if ($currentTestData.testparams)
		{
			foreach ($param in $currentTestData.testparams.param)
			{
				($param) | out-file -encoding ASCII -append -filePath $constFile
			}
		}		

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $constFile -username $user -password $password -upload 
		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo

		LogMsg "Executing : $($currentTestData.testScript)"
		$KernelVersion=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -r 2>&1" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash Perf_BuildKernel.sh > Perf_BuildKernel.log 2>&1" -runAsSudo -runmaxallowedtime 12000 -ignoreLinuxExitCode
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Perf_BuildKernel.log $($currentTestData.testScript).log" -runAsSudo
		
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/state.txt, /home/$user/summary.log,/home/$user/$($currentTestData.testScript).log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
		$testSummary = Get-Content $LogDir\summary.log
		$testStatus = Get-Content $LogDir\state.txt

		if ($testStatus -eq "TestCompleted")
		{
			LogMsg "Test Completed"
			
			$temp = RetryOperation -operation { Restart-AzureVM -ServiceName $hs1vm1.ServiceName -Name $hs1vm1.Name -Verbose } -description "Restarting VM.." -maxRetryCount 10 -retryInterval 5
			if ( $temp.OperationStatus -eq "Succeeded" )
			{
				LogMsg "Restarted Successfully"
				if ((isAllSSHPortsEnabled -DeployedServices $testVMsinService.DeploymentName) -imatch "True")
				{
					foreach ($line in $testSummary)
					{
						if($line -imatch "failed" )
						{
							LogErr "$line"
						}
						else
						{
							LogMsg "$line"
						}
					}
					if(($testSummary -imatch "make oldconfig: Success" -and $testSummary -imatch "make: Success" -and $testSummary -imatch "make modules_install: Success" -and $testSummary -imatch "make install: Success") -or (($testSummary | Select-String -Pattern "Success").length -eq 4))
					{
						$NewKernelVersion=RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -r 2>&1" -runAsSudo
						$NewKernelVersion > $LogDir\NewKernelVersion.txt
						if(!($NewKernelVersion -imatch $KernelVersion))
						{
							$testResult = "PASS"
							LogMsg "Test result : $testResult"
							$metaData = ""
							GetVMLogs -DeployedServices $isDeployed
							$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/usr/sbin/waagent -force -deprovision+user 2>&1" -runAsSudo
							if($output -match "home directory will be deleted")
							{
								LogMsg "** VM De-provisioned Successfully **"
								$CaptureImageName = CaptureVMImage -ServiceName $isDeployed
								LogMsg "** CAPUTRED IMAGE NAME:  $CaptureImageName **"
								write-host "** Captured Image for Benchmark test:  $CaptureImageName **"
								$CaptureImageName > $LogDir\CapturedImageInfo.txt
							}
						}
						else{
						$testResult = "FAIL"
						LogErr "Test result : $testResult"
						$metaData = ""
						GetVMLogs -DeployedServices $isDeployed
						}
						LogMsg "Kernel Version : $KernelVersion"
						LogMsg "New Kernel Version : $NewKernelVersion"
					}
					else{
						$testResult = "FAIL"
						LogErr "Test result : $testResult"
						$metaData = ""
						GetVMLogs -DeployedServices $isDeployed
					}
				}
			}
			else
			{
				Throw "Error in VM Restart."
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
