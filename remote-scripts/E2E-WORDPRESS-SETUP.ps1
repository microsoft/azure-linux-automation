<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$passwd = $password.Replace('"','')

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

if ($isDeployed)
{
	try
	{
		LogMsg "TEST VM : $($allVMData.ServiceName)"
		try{
			if($currentTestData.E2ESetupCmdLineArgument -imatch "singleVM_setup")
			{
				#region FOR WORDPRESS 1 VM TEST
				write-host "Preparing WordPress SingleVM Setup"
				[string] $ServiceName = $allVMData.ServiceName
				$hs1vm1sshport = $allVMData.SSHPort
				$hs1bkvmurl = $allVMData.URL
				$wordpressUrl  = "http://"+$hs1bkvmurl+"/wordpress/wp-admin/install.php"
				$hs1vm1Hostname = $allVMData.RoleName
				$hs1VIP = $allVMData.PublicIP
				$hs1IP = $allVMData.InternalIP
				
				LogMsg "TEST VM details :"
				LogMsg "  RoleName : $hs1vm1Hostname"
				LogMsg "  Public IP : $hs1VIP"
				LogMsg "  SSH Port : $hs1vm1sshport"
				LogMsg "  WORDPRESS URL : $wordpressUrl"
	
				Set-Content -Value "#all the IPs should be Internal ips `n<username>$user</username>`n<password>$passwd</password>" -Path "$LogDir\wordpress_install.XML"
				# Uploading files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files ".\$LogDir\wordpress_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				# Assiging Permissions to uploaded files into VM
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null

				LogMsg "Executing : $($currentTestData.testScript)"
				#region EXECUTE TEST
				Set-Content -Value "python $($currentTestData.testScript) singleVM_setup 2>&1> /home/$user/wordpressConsole.txt" -Path "$LogDir\StartWordpressTest.sh"
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files ".\$LogDir\StartWordpressTest.sh" -username $user -password $password -upload
				# Wordpress installation on E2ESingleVM"
				Write-host "#################################################################################################"
				Write-host ""
				Write-host "Wordpress installation has been started on E2ESingleVM..." -foregroundcolor "magenta"
				Write-host "It will take more than 20 minutes and may even take more time depending on internet speed." -foregroundcolor "magenta"
				Write-host ""
				Write-host "#################################################################################################"
				# Wordpress Setup file is executing on E2ESingleVM"
				$testJob = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash /home/$user/StartWordpressTest.sh" -runAsSudo -RunInBackground
				#region MONITOR TEST
				while ( (Get-Job -Id $testJob).State -eq "Running" )
				{
					 $wordpressTestInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat /home/$user/Runtime.log | grep 'INFO :' | tail -2 " -runAsSudo 
					 LogMsg "** Current TEST Staus : $wordpressTestInfo"
					 WaitFor -seconds 2
				}
				# Downloading the files VM		
				RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/wdp_test.txt , /home/$user/logs.tar.gz" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
			}
			elseif($currentTestData.E2ESetupCmdLineArgument -imatch "loadbalancer_setup")
			{	
				#region FOR WORDPRESS 4 VM TEST
				write-host "Preparing WordPress FourVM Setup"
				$noFrontend = $true
				$noBackend = $true
				foreach ( $vmData in $allVMData )
				{
					if ( $vmData.RoleName -imatch "Frontend1" )
					{
						$fronend1VMData = $vmData
						$noFrontend = $false
					}
					elseif ( $vmData.RoleName -imatch "Frontend2" )
					{
						$fronend2VMData = $vmData
						$noFrontend = $false
					}
					elseif ( $vmData.RoleName -imatch "Frontend3" )
					{
						$fronend3VMData = $vmData
						$noFrontend = $false
					}
					elseif ( $vmData.RoleName -imatch "Backend" )
					{
						$noBackend = $fase
						$backendVMData = $vmData
					}
				}
				if ( $noFrontend )
				{
					Throw "No any slave VM defined. Be sure that, Server machine role names matches with pattern `"*slave*`" Aborting Test."
				}
				if ( $noBackend )
				{
					Throw "No any master VM defined. Be sure that, Client VM role name matches with the pattern `"*master*`". Aborting Test."
				}
				
				$hs1bkvmurl = $allVMData.url[0]
				$wordpressUrl  = "http://"+$hs1bkvmurl+"/wordpress/wp-admin/install.php"
				
				LogMsg "FRONTEND VM details :"
				LogMsg "  RoleName : $($fronend1VMData.RoleName)"
				LogMsg "  Public IP : $($fronend1VMData.PublicIP)"
				LogMsg "  SSH Port : $($fronend1VMData.SSHPort)"
				
				LogMsg "  RoleName : $($fronend2VMData.RoleName)"
				LogMsg "  Public IP : $($fronend2VMData.PublicIP)"
				LogMsg "  SSH Port : $($fronend2VMData.SSHPort)"
				
				LogMsg "  RoleName : $($fronend3VMData.RoleName)"
				LogMsg "  Public IP : $($fronend3VMData.PublicIP)"
				LogMsg "  SSH Port : $($fronend3VMData.SSHPort)"
				
				LogMsg "BACKEND VM details :"
				LogMsg "  RoleName : $($backendVMData.RoleName)"
				LogMsg "  Public IP : $($backendVMData.PublicIP)"
				LogMsg "  SSH Port : $($backendVMData.SSHPort)"
				LogMsg "  WORDPRESS URL : $wordpressUrl"
				
				$hs1VIP = $backendVMData.PublicIP
				[string] $ServiceName = $allVMData.ServiceName
				
				$bkendip = $backendVMData.InternalIP.ToString()
				$fe1ip = $fronend1VMData.InternalIP.ToString()
				$fe2ip = $fronend2VMData.InternalIP.ToString()
				$fe3ip = $fronend3VMData.InternalIP.ToString()
				
				$hs1bkvmsshport = $backendVMData.SSHPort
				$fe1sshport = $fronend1VMData.SSHPort
				$fe2sshport = $fronend2VMData.SSHPort
				$fe3sshport = $fronend3VMData.SSHPort
				
				#Preparation of wordpress install xml file
				Set-Content -Value "#all the IPs should be Internal ips `n<back_endVM_ip>$bkendip</back_endVM_ip>`n<front_endVM_ips>$fe1ip $fe2ip $fe3ip</front_endVM_ips>`n<username>$user</username>`n<password>$passwd</password>" -Path "$LogDir\wordpress_install.XML"
				# Uploading files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bkvmsshport -files ".\$LogDir\wordpress_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bkvmsshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				# Assiging Permissions to uploaded files into VM
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bkvmsshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null

				#region EXECUTE TEST
				Set-Content -Value "python $($currentTestData.testScript) loadbalancer_setup 2>&1 > /home/$user/wordpressConsole.txt" -Path "$LogDir\StartWordpressTest.sh"
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bkvmsshport -files ".\$LogDir\StartWordpressTest.sh" -username $user -password $password -upload
				LogMsg "Executing : $($currentTestData.testScript)"
				$cmdStr = '`date` INFO : Setup Not Started..'
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $fe1sshport -command "echo $cmdStr > /home/$user/Runtime.log" #-runAsSudo 
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $fe2sshport -command "echo $cmdStr > /home/$user/Runtime.log" #-runAsSudo 
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $fe3sshport -command "echo $cmdStr > /home/$user/Runtime.log" #-runAsSudo 
				# Wordpress installation on E2EFOURVM
				Write-host "#################################################################################################"
				Write-host ""
				Write-host "Wordpress installation has been started on E2EFOURVM..." -foregroundcolor "magenta"
				Write-host "It will take more than 30 minutes and may take more time depending on internet speed." -foregroundcolor "magenta"
				Write-host ""
				Write-host "#################################################################################################"
				# Read-host "Verify 4VM detais...."
				$testJob = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bkvmsshport -command "bash /home/$user/StartWordpressTest.sh" -runAsSudo -RunInBackground
				#region MONITOR TEST
				while ( (Get-Job -Id $testJob).State -eq "Running" )
				{
					$wordpressTestInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bkvmsshport -command "cat /home/$user/Runtime.log | grep 'INFO :' | tail -2 " -runAsSudo 
					LogMsg "** Current TEST Staus BACKEND : $wordpressTestInfo"
					$fe1TestInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $fe1sshport -command "cat /home/$user/Runtime.log | grep 'INFO :' | tail -2 " -runAsSudo -ignoreLinuxExitCode
					LogMsg "** Current TEST Staus of FRONTEND1 : $fe1TestInfo"
					$fe2TestInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $fe2sshport -command "cat /home/$user/Runtime.log | grep 'INFO :' | tail -2 " -runAsSudo -ignoreLinuxExitCode
					LogMsg "** Current TEST Staus of FRONTEND2 : $fe2TestInfo"
					$fe3TestInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $fe3sshport -command "cat /home/$user/Runtime.log | grep 'INFO :' | tail -2 " -runAsSudo -ignoreLinuxExitCode
					LogMsg "** Current TEST Staus of FRONTEND3 : $fe3TestInfo"
					WaitFor -seconds 10
				}
				RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/wdp_test.txt,/home/$user/logs.tar.gz " -downloadTo $LogDir -port $hs1bkvmsshport -username $user -password $password 2>&1 | Out-Null
			}else{
				$testResult="FAIL"
				LogErr "Command line argument not properly added for WordPress Setup, add the argument for FourVM: loadbalancer_setup, SingleVM: singleVM_setup in azure_ica_all.xml file at E2ESetupCmdLineArgument tag"
			}
#Verifying Wordpress setup id completed or not
			try{
				$out = Select-String -Simple "WDP_INSTALL_PASS"  $LogDir\wdp_test.txt
				if($out){
					write-host "Wordpress setup finished successfully."
					$testResult="PASS"

				}else{
					write-host "Wordpress setup failed."
					$testResult="FAIL"
				}
			}catch{
				write-host "Wordpress setup failed..."
				$testResult="FAIL"
			} 
		}
		catch{		
			$testResult="Aborted"
			LogMsg "Exception Detected in Wordpress.py"
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

#Verification of WordPress URL
try{
	WaitFor -seconds 120
	$webclient = New-Object System.Net.WebClient
	$webclient.DownloadFile($wordpressUrl,"$pwd\index.html")

	$out = Select-String -Simple WordPress index.html
	if($out){
		write-host "WordPress verification using url success." -foreground "white"
		$testResult="PASS"
	}else{
		write-host "WordPress verification using url failed." -foreground "white"
		$testResult="FAIL"
	}
}
catch
{
	write-host "WordPress verification using url failed..." -foreground "green"
	$testResult="FAIL"
}
$resultArr += $testResult
$result = GetFinalResultHeader -resultarr $resultArr
$result = $testResult

#Clean up the setup
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
if ($testResult -eq "PASS")
{
	Write-host "#################################################################################################"
	Write-host ""
	Write-host  "Open $wordpressUrl in the browser and you should be able to see the Wordpress installation page." -foregroundcolor "magenta"
	Write-host ""
	Write-host "#################################################################################################"
}
return $result
