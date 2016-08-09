<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$resultArr = @()
$Images = @()

$TestCount = $currentTestData.TestCount
$TestScripts = $currentTestData.testScript.Split(',')
$TestScript1 = $TestScripts[0]
$TestScript2 = $TestScripts[1]

$TestFiles = $currentTestData.files.Split(',')
$TestFile1 = $TestFiles[0]
$TestFile2 = $TestFiles[1]


LogMsg "test count: $TestCount"
#Test Starts Here..
$count = 0
$successCount = 0
$failCount = 0
$Distroes = ('Ubuntu Server 14.04 LTS','Ubuntu Server 15.10','Ubuntu Server 16.04 LTS')
foreach ($DistroName in $Distroes)
{
	$Images += (Get-AzureVMImage |  where {$_.ImageFamily -eq $DistroName} | sort PublishedDate -Descending)[0].ImageName
}
While ($count -lt $TestCount)
{
	$testResult = ""
	$count += 1
	LogMsg "ATTEMPT : $count/$TestCount"
	foreach ($newDistro in $xmlConfig.config.Azure.Deployment.Data.Distro)
	{ 
		if ($newDistro.Name -eq $Distro)
		{
			$randomImage = [String]($Images | Get-Random)			
			$newDistro.OsImage = $randomImage
			LogMsg "Using image: $($newDistro.OsImage)"
			break
		}
	}
	$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
	$NewLogDir = "$LogDir\ICA-MIRROR-TEST-$count"
	mkdir $NewLogDir
	if ($isDeployed)
	{
		try
		{
			$hs1VIP = $allVMData[0].PublicIP
			$hs1vm1sshport = $allVMData[0].SSHPort								
			$hs1vm2sshport = $allVMData[1].SSHPort

			RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $TestFile1 -username $user -password $password -upload
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo

			RemoteCopy -uploadTo $hs1VIP -port $hs1vm2sshport -files $TestFile2 -username $user -password $password -upload
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "chmod +x *" -runAsSudo
			
			LogMsg "Executing : $TestScript1"
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash $TestScript1" -runAsSudo -runMaxAllowedTime 1800
			LogMsg "Waiting 10 minutues for next execution"			
			WaitFor -minutes 10
			LogMsg "Executing : $TestScript2"
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "bash $TestScript2" -runAsSudo -runMaxAllowedTime 1800

			RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/Summary.log, /home/$user/$TestScript1.log" -downloadTo $NewLogDir -port $hs1vm1sshport -username $user -password $password
			$testResult1 = Get-Content $NewLogDir\Summary.log

			RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/Summary.log, /home/$user/$TestScript2.log" -downloadTo $NewLogDir -port $hs1vm2sshport -username $user -password $password
			$testResult2 = Get-Content $NewLogDir\Summary.log

			if($testResult1 -match 'PASS' -and $testResult2 -match 'PASS')
			{
				$testResult = 'PASS'
				$successCount += 1
			}
			else
			{
				$testResult = 'FAIL'
				$failCount += 1
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
	#Clean up the setup
	DoTestCleanUp -result $testResult -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed
}

LogMsg "Test Count: $TestCount PASS: $successCount FAIL: $failCount"
#Return the result and summery to the test suite script..
$result = GetFinalResultHeader -resultarr $resultArr
return $result
