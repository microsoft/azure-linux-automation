# This script deploys the VMs for the LVM functional test and trigger the test.
# 1. lvm2, iozone and dos2unix must be installed in the test image
#
# Author: Sivakanth R
# Email	: v-sirebb@microsoft.com
#
###################################################################################

<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$FunctionType = ""

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
		$allVMData  = GetAllDeployementData -DeployedServices $isDeployed
		Set-Variable -Name AllVMData -Value $allVMData
		[string] $ServiceName = $allVMData.ServiceName
		$hs1VIP = $allVMData.PublicIP
		$hs1ServiceUrl = $allVMData.URL
		$hs1vm1IP = $allVMData.InternalIP
		$hs1vm1Hostname = $allVMData.RoleName
		$hs1vm1sshport = $allVMData.SSHPort
		
		$FunctionType = $currentTestData.FunctionType
		$DiskParam = $currentTestData.DiskParam
		$DiskSize = $currentTestData.DiskSize
		$LunNumber = $currentTestData.LunNumber
		$Cache = $currentTestData.Cache
		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "dos2unix *.sh" -runAsSudo -ignoreLinuxExitCode
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *.sh" -runAsSudo
		
		$KernelVersion = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo 
		LogMsg "VM1 kernel version:- $KernelVersion"
		LogMsg "LVM functional $FunctionType test started with $Cache cache"
		
		if ($DiskParam -imatch "datadisk")
		{
			$temp = RetryOperation -operation { Get-AzureVM -ServiceName $ServiceName | Add-AzureDataDisk -CreateNew -DiskSizeInGB $DiskSize -LUN $LunNumber -HostCaching $Cache -DiskLabel "$ServiceName-Disk-$LunNumber" | Update-AzureVM } -description "Attaching $DiskSize GB disk to LUN : $LunNumber with caching : $Cache." -maxRetryCount 10 -retryInterval 5
			if ( $temp.OperationStatus -eq "Succeeded" )
			{
				LogMsg "Disk attached Successfully.."
				$LunNumber=$LunNumber+1
			}
		}
		
		$testJob = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash /home/$user/$($currentTestData.testScript) $user $DiskParam $FunctionType >> lvmFunctionTest.txt" -runAsSudo -RunInBackground
		#region MONITOR TEST
		$IsAttach = $true
		$IsDeattach = $true
		while ( (Get-Job -Id $testJob).State -eq "Running" )
		{
			$lvmTestInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "egrep ': Success|: Failed|please wait' /home/$user/lvmFunctionTest.txt | tail -1 " -runAsSudo -ignoreLinuxExitCode
			LogMsg "Current Test Staus : $lvmTestInfo"
			
			if($IsAttach)
			{
				LogMsg "Attach the data disk to VM"
				$AttachInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "grep -i 'Now Attach data disk for LVM test' /home/$user/lvmFunctionTest.txt" -runAsSudo -ignoreLinuxExitCode
				if ($AttachInfo -imatch "Now Attach data disk for LVM test")
				{
					$temp = RetryOperation -operation { Get-AzureVM -ServiceName $ServiceName | Add-AzureDataDisk -CreateNew -DiskSizeInGB $DiskSize -LUN $LunNumber -HostCaching $Cache -DiskLabel "$ServiceName-Disk-$LunNumber" | Update-AzureVM } -description "Attaching $DiskSize GB disk to LUN : $LunNumber with caching : $Cache." -maxRetryCount 10 -retryInterval 5
					if ( $temp.OperationStatus -eq "Succeeded" )
					{
						LogMsg "Data disk attached Successfully.."
						$IsAttach = $false
					}
					else
					{
						LogMsg "Data disk attach Failed.."
						$testResult = "FAIL"
					}
				}
			}
			if($FunctionType -imatch "Shrink")
			{
				if($IsDeattach)
				{
					LogMsg "Detach the data disk from VM"
					$DeattachInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "grep -i 'Now Deattach the data disk' /home/$user/lvmFunctionTest.txt" -runAsSudo -ignoreLinuxExitCode
					if ($DeattachInfo -imatch "Now Deattach the data disk")
					{
						$temp = RetryOperation -operation { Get-AzureVM -ServiceName $ServiceName | Remove-AzureDataDisk -DeleteVHD -LUN $LunNumber | Update-AzureVM –Verbose } -description "Removing disk from LUN : $LunNumber." -maxRetryCount 10 -retryInterval 5
						if ( $temp.OperationStatus -eq "Succeeded" )
						{
							LogMsg "Data disk deattached Successfully.."
							$IsDeattach = $false
						}
						else
						{
							LogMsg "Data disk deattach Failed.."
							$testResult = "FAIL"
						}
					}
				}
			}
			WaitFor -seconds 10
		}
		
		$lvmTesStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "grep -i 'LVM functionlal test completed' /home/$user/lvmFunctionTest.txt" -runAsSudo -ignoreLinuxExitCode
		if ($lvmTesStatus -imatch "LVM functionlal test completed")
		{
			LogMsg "LVM $FunctionType test COMPLETED.."
			$syslogStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/systemerrorlogs.txt" -runAsSudo -ignoreLinuxExitCode
			LogMsg "Verify the found syslog errors are ignorable or not in /home/$user/systemerrorlogs.txt `n $syslogStatus" 
			$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/logs.tar" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
			$testResult = "PASS"
		}
		else
		{
			LogMsg "LVM $FunctionType test FAILED.."
			$testResult = "FAIL"
		}
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
#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
