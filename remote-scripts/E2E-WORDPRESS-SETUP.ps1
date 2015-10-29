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
		$testServiceData = Get-AzureService -ServiceName $isDeployed

		#Get VMs deployed in the service..
		$testVMsinService = $testServiceData | Get-AzureVM
		try{
			if($currentTestData.E2ESetupCmdLineArgument -imatch "singleVM_setup")
			{
				write-host "Preparing WordPress SingleVM Setup"
				$hs1vm1 = $testVMsinService
				$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
				$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
				$hs1VIP = $hs1vm1Endpoints[0].Vip
				$wordpressUrl  = $hs1vm1.DNSName+"wordpress/wp-admin/install.php"
				$hs1ServiceUrl = $hs1vm1.DNSName
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
				$hs1vm1Hostname =  $hs1vm1.Name

				"#all the IPs should be Internal ips `n<username>$user</username>`n<password>$passwd</password>" > 'wordpress_install.XML'
				# Uploading files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files "wordpress_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
				# Uploading files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				# Assiging Permissions to uploaded files into VM
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
				# Converting the file from UTF-16 to ASCII
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "iconv -f UTF-16 -t ASCII wordpress_install.XML > wordpress_install.XML.tmp ; mv -f wordpress_install.XML.tmp wordpress_install.XML" -runAsSudo 2>&1 | Out-Null

				LogMsg "Executing : $($currentTestData.testScript)"
				# Wordpress installation on E2ESingleVM"
				Write-host "#################################################################################################"
				Write-host ""
				Write-host "Wordpress installation has been started on E2ESingleVM..." -foregroundcolor "magenta"
				Write-host "It will take more than 20 minutes and may even take more time depending on internet speed." -foregroundcolor "magenta"
				Write-host ""
				Write-host "#################################################################################################"
				# Wordpress Setup file is executing on E2ESingleVM"
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command " python $($currentTestData.testScript) singleVM_setup  2>&1 > print.log" -runAssudo -ignoreLinuxExitCode -runmaxallowedtime 3600 2>&1 | Out-Null
				# Downloading the files VM		
				RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/wdp_test.txt , /home/$user/logs.tar.gz" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
			}
			elseif($currentTestData.E2ESetupCmdLineArgument -imatch "loadbalancer_setup")
			{	
				write-host "Preparing WordPress FourVM Setup"
				$hs1bkvm = $testVMsinService[0]
				$hs1fe1vm1 = $testVMsinService[1]
				$hs1fe2vm2 = $testVMsinService[2]
				$hs1fe3vm3 = $testVMsinService[3]
				
				$hs1bkvmEndpoints = $hs1bkvm | Get-AzureEndpoint
				$hs1bkvmsshport = GetPort -Endpoints $hs1bkvmEndpoints -usage ssh
				
				$hs1VIP = $hs1bkvmEndpoints.Vip
				
				$wordpressUrl  = $hs1bkvm.DNSName+"wordpress/wp-admin/install.php"
				$hs1ServiceUrl = $hs1bkvm.DNSName
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
				
				$bkendip = $hs1bkvm.Ipaddress.ToString()
				$fe1ip = $hs1fe1vm1.Ipaddress.ToString()
				$fe2ip = $hs1fe2vm2.Ipaddress.ToString()
				$fe3ip = $hs1fe3vm3.Ipaddress.ToString()
				
				#Preparation of wordpress install xml file
				"#all the IPs should be Internal ips `n<back_endVM_ip>$bkendip</back_endVM_ip>`n<front_endVM_ips>$fe1ip $fe2ip $fe3ip</front_endVM_ips>`n<username>$user</username>`n<password>$passwd</password>" > 'wordpress_install.XML'
				# Uploading xml file into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bkvmsshport -files "wordpress_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
				# Uploading files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bkvmsshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				# Assiging Permissions to uploaded files into VM
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bkvmsshport -command "chmod 777 *.XML" -runAsSudo 2>&1 | Out-Null
				# Converting the file from UTF-16 to ASCII
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bkvmsshport -command "iconv -f UTF-16 -t ASCII wordpress_install.XML > wordpress_install.XML.tmp ; mv -f wordpress_install.XML.tmp wordpress_install.XML" -runAsSudo 2>&1 | Out-Null

				LogMsg "Executing : $($currentTestData.testScript)"
				# Wordpress installation on E2EFOURVM
				Write-host "#################################################################################################"
				Write-host ""
				Write-host "Wordpress installation has been started on E2EFOURVM..." -foregroundcolor "magenta"
				Write-host "It will take more than 30 minutes and may take more time depending on internet speed." -foregroundcolor "magenta"
				Write-host ""
				Write-host "#################################################################################################"
				# Wordpress Setup file is executing on E2EFOURVM
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bkvmsshport -command "python $($currentTestData.testScript) loadbalancer_setup 2>&1 > print.log" -runAsSudo -ignoreLinuxExitCode -runmaxallowedtime 3600 2>&1 | Out-Null 
				# Downloading the files VM
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
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

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
