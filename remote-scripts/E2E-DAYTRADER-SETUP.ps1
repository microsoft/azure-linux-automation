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
				write-host "Preparing Daytrader SingleVM Setup"
				$hs1vm1 = $testVMsinService
				$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
				$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
				$hs1VIP = $hs1vm1Endpoints[0].Vip
				$hs1ServiceUrl = $hs1vm1.DNSName
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")

				$wsurl = "http:`/`/"+$hs1ServiceUrl.Replace(" ","")+":8080"
				$dturl = "$wsurl`/daytrader"

				"#all the IPs should be Internal ips `n<username>$user</username>`n<password>$passwd</password>" > 'Daytrader_install.XML'
				# Uploading files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files "Daytrader_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
				# Assiging Permissions to uploaded files into VM
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
				
				# converting file format from UTF-16 to ASCII
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "iconv -f UTF-16 -t ASCII Daytrader_install.XML > Daytrader_install.XML.tmp ; mv -f Daytrader_install.XML.tmp Daytrader_install.XML" -runAsSudo 2>&1 | Out-Null
				
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *.XML" -runAsSudo 2>&1 | Out-Null	
				
				LogMsg "Executing : $($currentTestData.testScript)"
				Write-host "#################################################################################################"
				Write-host ""
				Write-host "Daytrader single vm installation has been started." -foregroundcolor "yellow"
				Write-host "It takes nearly 20 minutes and may take more time depending on internet speed." -foregroundcolor "yellow"
				Write-host ""
				Write-host "#################################################################################################"
				
				$dtr_setup_status = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python $($currentTestData.testScript) $($currentTestData.E2ESetupCmdLineArgument) 2>&1 > print.log" -runAsSudo 2>&1 | Out-Null
				
				Start-Sleep -s 120
				$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/test/dtr_test.txt, /home/test/logs.tar.gz" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password 2>&1 | Out-Null
			}
			elseif($currentTestData.E2ESetupCmdLineArgument -imatch "loadbalancer_setup")
			{
				$hs1bvm = $testVMsinService[0]
				$hs1fevm1 = $testVMsinService[1]
				$hs1fevm2 = $testVMsinService[2]
				$hs1fevm3 = $testVMsinService[3]
				$hs1bvmEndpoints = $hs1bvm | Get-AzureEndpoint
				$hs1bvmsshport = GetPort -Endpoints $hs1bvmEndpoints -usage ssh
				
				$hs1VIP = $hs1bvmEndpoints.Vip
				
				$hs1ServiceUrl = $hs1bvm.DNSName
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
				$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
				
				$wsurl = "http:`/`/"+$hs1ServiceUrl.Replace(" ","")+":8080"
				$dturl = "$wsurl`/daytrader"
				LogMsg "URL : $hs1ServiceUrl"
				
				$beip = $hs1bvm.Ipaddress.ToString()
				$fe1ip = $hs1fevm1.Ipaddress.ToString()
				$fe2ip = $hs1fevm2.Ipaddress.ToString()
				$fe3ip = $hs1fevm3.Ipaddress.ToString()
			
				$hs1fevm1Endpoints = $hs1fevm1 | Get-AzureEndpoint
				$hs1fevm1sshport = GetPort -Endpoints $hs1fevm1Endpoints -usage ssh
			
				$hs1fevm2Endpoints = $hs1fevm2 | Get-AzureEndpoint
				$hs1fevm2sshport = GetPort -Endpoints $hs1fevm2Endpoints -usage ssh
			
				$hs1fevm3Endpoints = $hs1fevm3 | Get-AzureEndpoint
				$hs1fevm3sshport = GetPort -Endpoints $hs1fevm3Endpoints -usage ssh
				
				#Preparation of daytrader install xml file
				"#all the IPs should be Internal ips `n<back_endVM_ip>$beip</back_endVM_ip>`n<front_endVM_ips>$fe1ip $fe2ip $fe3ip</front_endVM_ips>`n<username>$user</username>`n<password>$passwd</password>" > 'Daytrader_install.XML'
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bvmsshport -files "Daytrader_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
				Remove-Item Daytrader_install.XML
				
				$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bvmsshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
				#TODO fix ssh tcp alive issue
				# converting file format from UTF-16 to ASCII
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "iconv -f UTF-16 -t ASCII Daytrader_install.XML > Daytrader_install.XML.tmp ; mv -f Daytrader_install.XML.tmp Daytrader_install.XML" -runAsSudo 2>&1 | Out-Null
				#$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "iconv -f UTF-16 -t ASCII $($currentTestData.testScript) > Daytrader_install.py.tmp ; mv -f Daytrader_install.py.tmp $($currentTestData.testScript)" -runAsSudo 2>&1 | Out-Null

				LogMsg "Executing : $($currentTestData.testScript)"
                # Daytrader installation on E2EFOURVM
				Write-host "#################################################################################################"
				Write-host ""
				Write-host "Daytrader four vm installation has been started." -foregroundcolor "yellow"
				Write-host "It takes nearly 50 minutes and may take even more time depending on internet speed." -foregroundcolor "yellow"
				Write-host ""
				Write-host "#################################################################################################"

				#Here Daytrader setup is Executing...
				#TODO collect cmd argument from azure xml file and pass it to python 			
				$dtr_setup_status = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "python $($currentTestData.testScript) $($currentTestData.E2ESetupCmdLineArgument) 2>&1 > print.log" -runAsSudo 2>&1 | Out-Null
				#$dtr_setup_status = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "python $($currentTestData.testScript) loadbalancer_setup 2>&1 > print.log" -runAsSudo 2>&1 | Out-Null
				# TODO time out for single vm reboot
				$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/dtr_test.txt,/home/$user/logs.tar.gz" -downloadTo $LogDir -port $hs1bvmsshport -username $user -password $password 2>&1 | Out-Null
			}else{
				$testResult="FAIL"
				LogErr "Command line argument not properly added for Daytrader Setup, add the argument for FourVM: loadbalancer_setup, SingleVM: singleVM_setup in azure_ica_all.xml file at E2ESetupCmdLineArgument tag"
			}
#Verifying Daytrader setup id completed or not
			try{
				$out = Select-String -Simple "DTR_INSTALL_PASS"  $LogDir\dtr_test.txt
				if($out){
					write-host "Daytrader setup finished successfully."
					$testResult="PASS"

				}else{
					write-host "Daytrader setup failed."
					$testResult="FAIL"
				}
			}
			catch
			{
				 write-host "Daytrader setup failed..."
				$testResult="FAIL"
			}
		}catch{
			$testResult="Aborted"
			LogMsg "Exception Detected in execution of $($currentTestData.testScript)"
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

#Verification of Daytrader URL
try{
    $webclient = New-Object System.Net.WebClient
    $webclient.DownloadFile($dturl,"$pwd\daytrader.html")

    $out = Select-String -Simple  DayTrader daytrader.html
    if($out){
		write-host "Daytrader verification using url: $dturl success." 
		$testResult="PASS"
    }else{
		write-host "Daytrader verification using url: $dturl failed." 
		$testResult="FAIL"
    }
	Remove-Item daytrader.html
}catch{
     write-host "Daytrader verification using url: $dturl failed..." 
	 $testResult="FAIL"
}
$resultArr += $testResult
$result = $testResult

#Clean up the setup
#DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed
if ($testResult -eq "PASS")
{
	Write-host "#################################################################################################"
	Write-host ""
	Write-host  "Open $wsurl in the browser and you should be able to see the Websphere page." -foregroundcolor "yellow"
	Write-host  "Open $dturl in the browser and you should be able to see the Daytrader home page." -foregroundcolor "yellow"
	Write-host ""
	Write-host "#################################################################################################"
}
#Return the result and summery to the test suite script..
return $result
