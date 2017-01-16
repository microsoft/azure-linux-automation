# This script deploys the VMs for the LVM functional test and trigger the test.
# 1. dos2unix, tar, git, make must be installed in the test image
#
# Author: Sivakanth Rebba
# Email       : v-sirebb@microsoft.com
#
###################################################################################

<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force -Verbose:$false
$result = ""
$testResult = ""
$resultArr = @()

$SAName = $currentTestData.remoteSA
$SAPrimaryKey = (Get-AzureStorageKey -StorageAccountName $SAName).Primary
$SAContainer = $currentTestData.remoteSAContainer
$remoteDebPath = $currentTestData.remoteDEBPath
$imageType = $currentTestData.imageType
$BaseOsImageName = GetOSImageFromDistro -Distro $Distro -xmlConfig $xmlConfig
LogMsg "Remote Storage Account to copy deb package : $SAName"
Logmsg "Image type : $imageType"
if($imageType -imatch "Standard")
{
	LogMsg "BaseOsImageName : $BaseOsImageName"
	LogMsg "Collecting latest $imageType ubuntu image from Azure gallery.." 
	$latestLinuxImage = (Get-AzureVMImage | where {$_.ImageName -imatch "Ubuntu-16_04-LTS-amd64-server" } | sort PublishedDate -Descending)[0].ImageName
	LogMsg "Latest $imageType Image from Azure gallery : $latestLinuxImage"
	$latestOsImage = SetOSImageToDistro -Distro $Distro -xmlConfig $xmlConfig -ImageName $latestLinuxImage
	LogMsg "Is $imageType latestOsImage SET : $latestOsImage"
}
elseif($imageType -imatch "Daily")
{
	LogMsg "BaseOsImageName : $BaseOsImageName"
	LogMsg "Collecting latest ubuntu $imageType image from Azure gallery"
	$latestLinuxImage = (Get-AzureVMImage | where {$_.ImageName -imatch "Ubuntu_DAILY_BUILD-xenial-16_04-" } | sort PublishedDate -Descending)[0].ImageName
	LogMsg "Latest $imageType Image from Azure gallery : $latestLinuxImage"
	$latestOsImage = SetOSImageToDistro -Distro $Distro -xmlConfig $xmlConfig -ImageName $latestLinuxImage
	LogMsg "Is $imageType latestOsImage SET : $latestOsImage"
	
}

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
              
              $DetectedDistro = DetectLinuxDistro -VIP $hs1VIP -SSHport $hs1vm1sshport -testVMUser  $user -testVMPassword $password
              if ( $DetectedDistro -imatch "UBUNTU" )
              {
                     LogMsg "Installing basic required packages wget tar git dos2unix mdadm"
                     $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "apt-get install --force-yes -y wget tar git dos2unix" -runAsSudo 2>&1
                     
              }
              elseif(($DetectedDistro -imatch "SLES") -or ($DetectedDistro -imatch "SUSE"))
              {
                     LogMsg "Installing basic required packages wget tar git dos2unix"
                     $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "zypper --non-interactive install wget tar git dos2unix" -runAsSudo 2>&1
              }
              elseif(($DetectedDistro -imatch "CENTOS") -or ($DetectedDistro -imatch "REDHAT") -or ($DetectedDistro -imatch "ORACLE"))
              {
                     LogMsg "Installing basic required packages wget tar git dos2unix"
                     $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "yum install --nogpgcheck -y wget tar git dos2unix" -runAsSudo 2>&1
              }
              else
              {
                    LogMsg "Detect distro is unknown.."
              }
              $out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
              $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "dos2unix *.sh" -runAsSudo 2>&1 
              $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *.sh" -runAsSudo 2>&1
              
              $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mkdir -p code" -runAsSudo
              $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv *.sh code/" -runAsSudo
              $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x code/*.sh" -runAsSudo
                            
              LogMsg "Linux Next build deb package generate STARTED.."
              $KernelVersion = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -r 2>&1" -runAsSudo
              LogMsg "Kernel Version : $KernelVersion"
              
              Set-Content -Value "bash /home/$user/code/$($currentTestData.testScript) > /home/$user/code/linuxNextBuildTest.txt" -Path "$LogDir\StartTest.sh"
              $out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files ".\$LogDir\StartTest.sh" -username $user -password $password -upload
              $out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv StartTest.sh /home/$user/code/" -runAsSudo
              $testJob = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash /home/$user/code/StartTest.sh" -runAsSudo -RunInBackground
              #region MONITOR TEST
              while ( (Get-Job -Id $testJob).State -eq "Running" )
              {
                     $linuxNextBuildInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/linuxNextBuildTest.txt | tail -1 " -runAsSudo 
                     $BuildStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/build.log | tail -1 " -runAsSudo 
                     LogMsg "** Current TEST Staus : $linuxNextBuildInfo"
                     LogMsg "** Current BUILD Staus : $BuildStatus"
                     WaitFor -seconds 10
              }
              $testStartUpStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/state.txt" -runAsSudo 
              $linuxNextBuildInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/code/linuxNextBuildTest.txt " -runAsSudo 
              if (($testStartUpStatus -eq "TestCompleted") -or ($linuxNextBuildInfo -imatch "Updating test case state to completed"))
              {
                     LogMsg "Linux Next build deb package generated successfully download deb package from /home/$user/code."
                     
                     $debPackageStatus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "ls /home/$user/linux-image*.deb" -runAsSudo
                     if ($debPackageStatus -imatch "No such file or directory")
                     {
                           LogMsg "DEB package not availabe.. "
                           $testResult = "FAIL"
                           $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "LINUX-NEXT DEB CREATION" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
                     }
                     else
                     {
						LogMsg "Generation of deb package from Linux Next build is SUCCESS.."
						$testResult = "PASS"
						$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "LINUX-NEXT DEB CREATION" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						$defualtKernelVersion = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -r" -runAsSudo
						LogMsg "DEFAULT KERNEL VERSION : $defualtKernelVersion"
						LogMsg "Verification of created linux-next .deb package installtion .."
						$debCheckStattus = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "dpkg -i linux-image*.deb >> debPackageinstalltion.log" -runAsSudo
						$restartvmstatus = RestartAllDeployments -allVMData $allVMData
						if ($restartvmstatus -eq "True")
						{
							$testDuration=0
							LogMsg "VMs Restarted Successfully"
							$latestKernelVersion = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -r" -runAsSudo
							LogMsg "LATEST KERNEL VERSION : $latestKernelVersion"
							if(($latestKernelVersion -ne $defualtKernelVersion) -and ($latestKernelVersion -imatch "next"))
							{
								$testResult = "PASS"
								$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "LINUX-NEXT DEB INSTALLATION : $latestKernelVersion" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
								LogMsg "DEFAULT KERNEL VERSION : $defualtKernelVersion"
								LogMsg "LATEST KERNEL VERSION : $latestKernelVersion"
								$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/*.deb, /home/$user/code/*.txt, /home/$user/code/*.log, /home/$user/code/*.sh" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null						   
						        $debPackageName = (ls $LogDir  | where {$_.Name -imatch "linux-image"}).Name
						        $debPackageFilePath = "$LogDir\$debPackageName"
						        $debPackageUploadInfo = Set-AzureStorageBlobContent -File $debPackageFilePath -Container $SAContainer -Blob $debPackageName -Context (New-AzureStorageContext -StorageAccountName $SAName -StorageAccountKey $SAPrimaryKey) -Force ; $debPackageuploadStatus = $? 
						        $debPackageUploadInfo1 = Set-AzureStorageBlobContent -File $debPackageFilePath -Container $SAContainer -Blob "linuxnext-latest.deb" -Context (New-AzureStorageContext -StorageAccountName $SAName -StorageAccountKey $SAPrimaryKey) -Force ; $debPackageuploadStatus1 = $? 
						        if (($debPackageuploadStatus -imatch "True") -and ($debPackageuploadStatus1 -imatch "True"))
						        {
							
							        LogMsg "Uploading $debPackageName into $SAContainer container is SUCCESS"
							        LogMsg "Uploading linuxnext-latest.deb into $SAContainer container is SUCCESS"
							        LogMsg "*********************************** LINUX-NEXT DEB PACKAGE AVAILABLE LINKS ***********************************`n`n 	$remoteDebPath/$debPackageName`n`n 	$remoteDebPath/linuxnext-latest.deb`n`n******************************************************************##************************************##**********************************"
							        $testResult = "PASS"
							        $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "LINUX-NEXT DEB PACK UPLOAD" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						        }
						        else
						        {
							        LogMsg "$debPackageName upload is FAILED"
							        $testResult = "FAIL"
									$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "LINUX-NEXT DEB PACK UPLOAD" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						        }
							}
							else
							{
                                LogMsg "$debPackageName installation is FAILED"
							    $testResult = "FAIL"
                                $resultSummary +=  CreateResultSummary -testResult $testResult -metaData "LINUX-NEXT DEB CREATION" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
							}
                        }
                        else
                        {
                            LogMsg "Restart VM is FAILED" 
                            $testResult = "FAIL"  
                        }
						
                     }
              }
              else
              {
                     LogMsg "Linux Next build deb package generation is FAILED.."
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
			  #$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName # if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
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
return $result, $resultSummary 
