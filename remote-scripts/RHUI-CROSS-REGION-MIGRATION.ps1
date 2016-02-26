<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig -getLogsIfFailed $true
if ($isDeployed)
{

	try
	{
		$testServiceData = Get-AzureService -ServiceName $isDeployed
		$testVMsinService = $testServiceData | Get-AzureVM
		$hs1vm1Hostname =  $testVMsinService.Name
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
		
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "yum update -y" -runAsSudo -runMaxAllowedTime 1800
		$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "yum install PrepareRHUI -y" -runAsSudo
		if($output -imatch "parepare rhui installation successfully")
		{
			$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/usr/sbin/waagent -force -deprovision+user 2>&1" -runAsSudo								
			if($output -match "home directory will be deleted")
			{
				LogMsg "** VM De-provisioned Successfully **"
				LogMsg "Stopping a VM to prepare OS image : $hs1vm1Hostname"
				$tmp = Stop-AzureVM -ServiceName $isDeployed -Name $hs1vm1Hostname -Force
				LogMsg "VM stopped successful.."
						
				LogMsg "Capturing the OS Image"
				$NewImageName = $isDeployed + '-prepared'
				$tmp = Save-AzureVMImage -ServiceName $isDeployed -Name $hs1vm1Hostname -NewImageName $NewImageName -NewImageLabel $NewImageName
				LogMsg "Successfully captured VM image : $NewImageName"
				#Remove the Cloud Service
				LogMsg "Executing: Remove-AzureService -ServiceName $isDeployed -Force"
				Remove-AzureService -ServiceName $isDeployed -Force

				#Copy prepared vhd from source region to dest region
				$SrcUri = (Get-AzureVMImage -ImageName $NewImageName).MediaLink
				$VHDNameWithoutExtension = $Distro + "-" + (Get-Date -Format 'yyyyMMddhhmmss').ToString() + "-cloud-prepared"
				$PreparedVHDCloud = $VHDNameWithoutExtension + ".vhd"

				$srcStorageAccount = $xmlConfig.config.Azure.General.StorageAccount
				$srcStorageKey = (Get-AzureStorageKey -StorageAccountName $SrcStorageAccount).Primary
				$srcContext = New-AzureStorageContext -StorageAccountName $srcStorageAccount -StorageAccountKey $srcStorageKey
							
				$destStorageAccount = $currentTestData.TestParameters.destStorageAccount
				$destContainerName= $currentTestData.TestParameters.destContainer
				$destStorageKey= (Get-AzureStorageKey -StorageAccountName $destStorageAccount).Primary
				$destContext = New-AzureStorageContext -StorageAccountName $destStorageAccount -StorageAccountKey $destStorageKey
					
				LogMsg "Executing: Start-AzureStorageBlobCopy -SrcUri $srcUri -SrcContext $srcContext -DestContainer $destContainerName -DestBlob $PreparedVHDCloud -DestContext $destContext"
				$blob = Start-AzureStorageBlobCopy -SrcUri $srcUri -SrcContext $srcContext -DestContainer $destContainerName -DestBlob $PreparedVHDCloud -DestContext $destContext
				while ($True)
				{
					$status = ($blob | Get-AzureStorageBlobCopyState).Status
					if ($status -eq "Success")
					{
						LogMsg "Status: copy prepared VHD $status!"
						break
					}
					elseif (($status -eq "Fail") -or (-not $status))
					{
						LogMsg "Error: Start-CopyAzureStorageBlob failed."
						Throw "Start-CopyAzureStorageBlob failed."
					}	
					else
					{
						LogMsg "Status: $status. Waiting for VHD copy operation..."
						Start-Sleep 30
					}
				}
					
				# create a new prepared image for cloud
				LogMsg "To create a new prepared image with the prepared VHD for cloud..."
				$cloudPreparedImageName = $Distro + "-" + (Get-Date -Format 'yyyyMMddhhmmss').ToString() + "-cloud-prepared"
				$link = "https://$destStorageAccount.blob.core.windows.net/$destContainerName/$preparedVHDCloud"
				LogMsg "Executing: Add-AzureVMImage -ImageName $cloudPreparedImageName -MediaLocation $link -OS Linux -Label $cloudPreparedImageName"
				Add-AzureVMImage -ImageName $cloudPreparedImageName -MediaLocation $link -OS Linux -Label $cloudPreparedImageName
					
				#Update xmlConfig using the CICloudEnvironmentDestConfigFile for cloud test					
				$CloudConfigXmlAzureGeneral = $xmlConfig.config.Azure.General
				$CloudConfigXmlAzureGeneral.Location = $currentTestData.TestParameters.destLocation
				$CloudConfigXmlAzureGeneral.StorageAccount = $destStorageAccount
				$xmlConfig.config.Azure.Deployment.$setupType.isDeployed = "NO"
				#Update Image
				$deploymentData = $xmlConfig.config.Azure.Deployment.Data
				$deploymentData.Distro[0].Name = $Distro
				$deploymentData.Distro[0].OsImage = $cloudPreparedImageName
					
				#Run cloud test case
				$AzureSetup = $xmlConfig.config.Azure.General
				LogMsg "Start run test ..."
				LogMsg "Setting Azure Subscription ..."
				Set-AzureSubscription -CurrentStorageAccountName $destStorageAccount -SubscriptionName $AzureSetup.SubscriptionName
				$currentSubscription = Get-AzureSubscription -SubscriptionId $AzureSetup.SubscriptionID -ExtendedDetails
				LogMsg "SubscriptionName       : $($currentSubscription.SubscriptionName)"
				LogMsg "SubscriptionId         : $($currentSubscription.SubscriptionID)"
				LogMsg "ServiceEndpoint        : $($currentSubscription.ServiceEndpoint)"
				LogMsg "CurrentStorageAccount  : $($AzureSetup.StorageAccount)"
					
				$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
				if($isDeployed)
				{
					$hs1VIP = $AllVMData.PublicIP
					$hs1vm1sshport = $AllVMData.SSHPort
					$hs1ServiceUrl = $AllVMData.URL
					$hs1vm1Dip = $AllVMData.InternalIP
					RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "yum update -y" -runAsSudo -runMaxAllowedTime 1800
					RemoteCopy -download -downloadFrom $hs1VIP -files "/etc/yum.repos.d/rhui-load-balancers" -downloadTo ..\CI -port $hs1vm1sshport -username $user -password $password
					if(Test-path ..\CI\rhui-load-balancers)
					{
						$info = Get-Content ..\CI\rhui-load-balancers
						LogMsg "The content of file rhui-load-balancers : "
						foreach ($str in $info)
						{
							LogMsg "$str"
						}							
						$testResult = 'PASS'
					}
					else
					{
						$testResult = 'FAIL'
					}
					LogMsg "Test result : $testResult"
					LogMsg "Test Completed"
				}
				else
				{
					$testResult = "Aborted"
					$resultArr += $testResult
				}
			}
			else
			{
				LogMsg "** VM De-provision Failed**"
				$testResult = "FAIL"
				LogMsg "Test result : $testResult"
			}				
		}
		else
		{
			LogMsg "Failed to install package PrepareRHUI."
			$testResult = "FAIL"
			LogMsg "Test result : $testResult"
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
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
