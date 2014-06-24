<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()


$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
#$isDeployed = "ICA-E2EFourVM-CentOS65-3-25-6-17-0"
if ($isDeployed)
{

	try
	{
		$testServiceData = Get-AzureService -ServiceName $isDeployed

		#Get VMs deployed in the service..
		$testVMsinService = $testServiceData | Get-AzureVM

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
		
		$wsurl = "http:`/`/"+$hs1ServiceUrl.Replace(" ","")+":8080"
		$dturl = "$wsurl`/daytrader"
		LogMsg "URL : $hs1ServiceUrl"
		#$hs1fevm3VIP = $hs1bvmEndpoints.Vip
		
		#Preparation of daytrader install xml file
		#$ipinfo = "#all the IPs should be Internal ips `n"
		#$ipinfo = "#all the IPs should be Internal ips `n<back_endVM_ip>$beip</back_endVM_ip>`n<front_endVM_ips>$fe1ip $fe2ip $fe3ip</front_endVM_ips>" 
		#$ipinfo > 'Daytrader_install.xml'
		"#all the IPs should be Internal ips `n<back_endVM_ip>$beip</back_endVM_ip>`n<front_endVM_ips>$fe1ip $fe2ip $fe3ip</front_endVM_ips>`n<front_endVM_username>test</front_endVM_username>`n<front_endVM_password>Redhat.Redhat.777</front_endVM_password>" > 'Daytrader_install.XML'
		$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bvmsshport -files "Daytrader_install.XML" -username $user -password $password -upload 2>&1 | Out-Null
		
		
		$out = RemoteCopy -uploadTo $hs1VIP -port $hs1bvmsshport -files $currentTestData.files -username $user -password $password -upload 2>&1 | Out-Null
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null
		# converting file format from UTF-16 to ASCII
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "iconv -f UTF-16 -t ASCII Daytrader_install.XML > Daytrader_install.XML.tmp ; mv -f Daytrader_install.XML.tmp Daytrader_install.XML" -runAsSudo 2>&1 | Out-Null
		
		
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "chmod +x *.XML" -runAsSudo 2>&1 | Out-Null
		try{
			LogMsg "Executing : $($currentTestData.testScript)"
			Write-host "#################################################################################################"
			Write-host ""
			Write-host "Daytrader four vm installation has been started." -foregroundcolor "yellow"
			Write-host "It takes nearly 50 minutes and may take even more time depending on internet speed." -foregroundcolor "yellow"
			Write-host ""
			Write-host "#################################################################################################"

			#$Tempout = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python $($currentTestData.testScript) singleVM_setup" -runAsSudo
#Here Daytrader setup is Executing...			
			$dtr_setup_status = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1bvmsshport -command "python $($currentTestData.testScript) loadbalancer_setup" -runAsSudo 2>&1 | Out-Null
			$out = RemoteCopy -download -downloadFrom $hs1VIP -files "/home/test/dtr_test.txt" -downloadTo $LogDir -port $hs1bvmsshport -username $user -password $password 2>&1 | Out-Null
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
			}catch{
				 write-host "Daytrader setup failed..."
				$testResult="FAIL"
			}
		}
		catch{
			$testResult="FAIL"
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
		write-host "Daytrader verification using url success." 
		$testResult="PASS"
    }else{
		write-host "Daytrader verification using url failed." 
		$testResult="FAIL"
    }
}
catch
{
     write-host "Daytrader verification using url failed..."
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
