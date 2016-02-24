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
		#Replace packages config file
		Copy-Item .\remote-scripts\packages-for-migration.xml .\remote-scripts\packages.xml
		$testServiceData = Get-AzureService -ServiceName $isDeployed
		$testVMsinService = $testServiceData | Get-AzureVM
		$hs1vm1Hostname =  $testVMsinService.Name
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
		
        RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload -doNotCompress
        RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo

        LogMsg "Executing : $($currentTestData.testScript)"
		$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "$python_cmd ./$($currentTestData.testScript)" -runAsSudo -runMaxAllowedTime 1800
		$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls /home/$user/SetupStatus.txt  2>&1" -runAsSudo
		if($output -imatch "/home/$user/SetupStatus.txt")
		{
			$SetupStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/SetupStatus.txt" -runAsSudo
			if($SetupStatus -imatch "PACKAGE-INSTALL-CONFIG-PASS")
			{
				LogMsg "** All the required packages for the distro installed successfully **"
				#Check whether the distro is using python2 and python3 to run waagent
				$usePython3 = $false
                $output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ps -ef | grep waagent | grep -v 'grep'" -runAsSudo
                if($output -match 'python3')
				{
					$usePython3 = $true
				}				
				#VM De-provision
				if($usePython3)
				{
					$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/usr/bin/python3 /usr/sbin/waagent -force -deprovision+user 2>&1" -runAsSudo					
				}
				else
				{
					$output = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/usr/sbin/waagent -force -deprovision+user 2>&1" -runAsSudo
				}
				
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
					[string]$EnvSrcConfigFile = ($env:CICloudEnvironmentConfigFile).ToString().trim()
					[string]$EnvDestConfigFile = ($env:CICloudEnvironmentDestConfigFile).ToString().trim()

					[xml]$SrcEnvXml = Get-Content "..\CI\Cloud\EnvConfigFiles\$EnvSrcConfigFile"
					$srcStorageAccount = $SrcEnvXml.config.Azure.General.StorageAccount
					$srcStorageKey= $SrcEnvXml.config.CIEnv.StorageAccountKey
					$srcContext = New-AzureStorageContext -StorageAccountName $srcStorageAccount -StorageAccountKey $srcStorageKey

					[xml]$DestEnvXml = Get-Content "..\CI\Cloud\EnvConfigFiles\$EnvDestConfigFile"				
					$destStorageAccount = $DestEnvXml.config.Azure.General.StorageAccount
					$destStorageKey= $DestEnvXml.config.CIEnv.StorageAccountKey
					$destContainerName= $DestEnvXml.config.CIEnv.PreparedContainer
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
					$CloudConfigXmlAzureGeneral.Location = $DestEnvXml.config.Azure.General.Location
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
					$out = SetSubscription -subscriptionID $AzureSetup.SubscriptionID -subscriptionName $AzureSetup.SubscriptionName -certificateThumbprint $AzureSetup.CertificateThumbprint -managementEndpoint $AzureSetup.ManagementEndpoint -storageAccount $AzureSetup.StorageAccount
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
				$testResult = "FAIL"
				LogMsg "Test result : $testResult"
			}
		}
		else
		{
			$testResult = "FAIL"
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
