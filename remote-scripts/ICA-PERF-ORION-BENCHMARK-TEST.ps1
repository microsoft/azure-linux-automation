<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

if ($isDeployed)
{
	try
	{
		$clientVMData = $allVMData
		#region Get the info about the disks
		$fdiskOutput = RunLinuxCmd -username $user -password $password -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -command "$fdisk -l" -runAsSudo
		$allDetectedDisks = GetNewPhysicalDiskNames -FdiskOutputBeforeAddingDisk "Disk /dev/sda`nDisk /dev/sdb" -FdiskOutputAfterAddingDisk $fdiskOutput

		#/dev/sda is OS disk and and /dev/sdb is the resource disk. So we will count the disks from /dev/sdc.
		$detectedTestDisks = ""
		foreach ( $disk in $allDetectedDisks.split("^"))
		{
			if (( $disk -eq "/dev/sda") -or ($disk -eq "/dev/sdb"))
			{
				#SKIP adding the disk to detected test disk list.
			}
			else
			{
				if ( $detectedTestDisks )
				{
					$detectedTestDisks += "^" + $disk
				}
				else
				{
					$detectedTestDisks = $disk
				}
			}
		}
		#endregion
		
		LogMsg "Generating constansts.sh ..."
		$constantsFile = ".\$LogDir\constants.sh"
		foreach ($testParam in $currentTestData.TestParameters.param )
		{
			Add-Content -Value "$testParam" -Path $constantsFile
			LogMsg "$testParam added to constansts.sh"
		}

		LogMsg "Generating orion.lun..."
		$orionLunFile = "orion.lun"
		$orionLunFilePath = "$LogDir\$orionLunFile"

		foreach ( $disk in $detectedTestDisks.split("^"))
		{
			Add-Content -Value $disk -Path $orionLunFilePath
		}
	
		#region EXECUTE TEST
		Set-Content -Value "./perf_orion.sh &> orionConsoleLogs.txt" -Path "$LogDir\StartOrionTest.sh"
		RemoteCopy -uploadTo $clientVMData.PublicIP -port $clientVMData.SSHPort -files "$constantsFile,.\$orionLunFilePath,.\remote-scripts\perf_orion.sh,.\$LogDir\StartOrionTest.sh" -username $user -password $password -upload
		$out = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -command "chmod +x *.sh" -runAsSudo
		$testJob = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -command "./StartOrionTest.sh" -RunInBackground -runAsSudo
		#endregion

		#region MONITOR TEST
		while ( (Get-Job -Id $testJob).State -eq "Running" )
		{
			$currentStatus = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -command "tail -n 1 orionTest.log"
			LogMsg "Current Test Staus : $currentStatus"
			WaitFor -seconds 20
		}
		$finalStatus = RunLinuxCmd -ip $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -command "cat state.txt"
		RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "orionTest.log"
		RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "orionConsoleLogs.txt"
		
		#region Analyse results..
		RemoteCopy -downloadFrom $clientVMData.PublicIP -port $clientVMData.SSHPort -username $user -password $password -download -downloadTo $LogDir -files "orion-*"

		$resultSummary = $null
		#
		#THIS FUNCTION WILL CREATE A NEW FOLDER FOR EACH TEST TYPE AND IT WILL PLACE RELATED LOG FILES IN THAT FOLDER.
		#
		Function SortOrionLogs($testType)
		{
			mkdir -Path "$LogDir\$testType" -Force | Out-Null
			foreach ( $file in (Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "orion-") -and ( $_.Name -imatch "-$testType-")} ) )
			{
				Move-Item -Path "$LogDir\$($file.Name)" -Destination "$LogDir\$testType" -Force | Out-Null
				LogMsg "$($file.Name) downloaded and moved to folder $testType"
			}
		}

		$testType = "oltp"
		LogMsg "Analysing '$testType' log files.."
		$oltpResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$oltpResult = ($oltpResultContents | where { $_ -imatch  "Maximum Small IOPS" })
		if ( $oltpResult )
		{
			$resultSummary +=  CreateResultSummary -testResult $oltpResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$oltpResult = ($oltpResultContents | where { $_ -imatch  "Minimum Small Latency"})
			$resultSummary +=  CreateResultSummary -testResult $oltpResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "dss"
		LogMsg "Analysing '$testType' log files.."
		$dssResultContents =  Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$dssResult = ($dssResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $dssResult )
		{
			$resultSummary +=  CreateResultSummary -testResult $dssResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "simple"
		LogMsg "Analysing '$testType' log files.."
		$simpleResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$simpleResult = ($simpleResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $simpleResult )
		{
			$resultSummary +=  CreateResultSummary -testResult $simpleResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$simpleResult = ($simpleResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $simpleResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$simpleResult = ($simpleResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $simpleResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "normal#1"
		LogMsg "Analysing '$testType' log files.."
		$normal1ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$normal1Result = ($normal1ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $normal1Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $normal1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$normal1Result = ($normal1ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $normal1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$normal1Result = ($normal1ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $normal1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "normal#2"
		LogMsg "Analysing '$testType' log files.."
		$normal2ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$normal2Result = ($normal2ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $normal2Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $normal2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$normal2Result = ($normal2ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $normal2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$normal2Result = ($normal2ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $normal2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "normal#3"
		LogMsg "Analysing '$testType' log files.."
		$normal3ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$normal3Result = ($normal3ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $normal3Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $normal3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$normal3Result = ($normal3ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $normal3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$normal3Result = ($normal3ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $normal3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType
		

		$testType = "oltpWrite100"
		LogMsg "Analysing '$testType' log files.."
		$oltpWrite100ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$oltpWrite100Result = ($oltpWrite100ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
		if ( $oltpWrite100Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $oltpWrite100Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$oltpWrite100Result = ($oltpWrite100ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $oltpWrite100Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "dssWrite100"
		LogMsg "Analysing '$testType' log files.."
		$dssWrite100ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$dssWrite100Result = ($dssWrite100ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $dssWrite100Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $dssWrite100Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "advancedWrite100Basic"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite100BasicResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite100BasicResult = ($advancedWrite100BasicResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite100BasicResult )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100BasicResult = ($advancedWrite100BasicResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100BasicResult = ($advancedWrite100BasicResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "advancedWrite100Detailed#1"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite100Detailed1ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite100Detailed1Result = ($advancedWrite100Detailed1ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite100Detailed1Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100Detailed1Result = ($advancedWrite100Detailed1ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100Detailed1Result = ($advancedWrite100Detailed1ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "advancedWrite100Detailed#2"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite100Detailed2ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite100Detailed2Result = ($advancedWrite100Detailed2ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite100Detailed2Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100Detailed2Result = ($advancedWrite100Detailed2ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100Detailed2Result = ($advancedWrite100Detailed2ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "advancedWrite100Detailed#3"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite100Detailed3ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite100Detailed3Result = ($advancedWrite100Detailed3ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite100Detailed3Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100Detailed3Result = ($advancedWrite100Detailed3ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite100Detailed3Result = ($advancedWrite100Detailed3ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite100Detailed3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "oltpWrite50"
		LogMsg "Analysing '$testType' log files.."
		$oltpWrite50ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$oltpWrite50Result = ($oltpWrite50ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
		if ( $oltpWrite50Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $oltpWrite50Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$oltpWrite50Result = ($oltpWrite50ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $oltpWrite50Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "dssWrite50"
		LogMsg "Analysing '$testType' log files.."
		$dssWrite50ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$dssWrite50Result = ($dssWrite50ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $dssWrite50Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $dssWrite50Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "advancedWrite50Basic"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite50BasicResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite50BasicResult = ($advancedWrite50BasicResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite50BasicResult )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50BasicResult = ($advancedWrite50BasicResultContents | where { $_ -imatch  "Maximum Large MBPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50BasicResult = ($advancedWrite50BasicResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50BasicResult = ($advancedWrite50BasicResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50BasicResult -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "advancedWrite50Detailed#1"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite50Detailed1ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite50Detailed1Result = ($advancedWrite50Detailed1ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite50Detailed1Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50Detailed1Result = ($advancedWrite50Detailed1ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50Detailed1Result = ($advancedWrite50Detailed1ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed1Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType


		$testType = "advancedWrite50Detailed#2"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite50Detailed2ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite50Detailed2Result = ($advancedWrite50Detailed2ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite50Detailed2Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50Detailed2Result = ($advancedWrite50Detailed2ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50Detailed2Result = ($advancedWrite50Detailed2ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed2Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		$testType = "advancedWrite50Detailed#3"
		LogMsg "Analysing '$testType' log files.."
		$advancedWrite50Detailed3ResultContents = Get-Content -Path "$LogDir\$((Get-ChildItem -Path $LogDir | where { ( $_.Name -imatch "-summary.txt") -and ( $_.Name -imatch "-$testType-") }).Name )"
		$advancedWrite50Detailed3Result = ($advancedWrite50Detailed3ResultContents | where { $_ -imatch  "Maximum Large MBPS" })
		if ( $advancedWrite50Detailed3Result )
		{
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50Detailed3Result = ($advancedWrite50Detailed3ResultContents | where { $_ -imatch  "Maximum Small IOPS" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
			$advancedWrite50Detailed3Result = ($advancedWrite50Detailed3ResultContents | where { $_ -imatch  "Minimum Small Latency" })
			$resultSummary +=  CreateResultSummary -testResult $advancedWrite50Detailed3Result -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		else
		{
			$resultSummary +=  CreateResultSummary -testResult "ERROR: Result Strings not found. Possible test error." -metaData $testType -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		}
		SortOrionLogs -testType $testType

		LogMsg "Analysis complete!"

		#endregion
		
		if ( $finalStatus -imatch "TestFailed")
		{
			LogErr "Test failed. Last known status : $currentStatus."
			$testResult = "FAIL"
		}
		elseif ( $finalStatus -imatch "TestAborted")
		{
			LogErr "Test Aborted. Last known status : $currentStatus."
			$testResult = "ABORTED"
		}
		elseif ( $finalStatus -imatch "TestCompleted")
		{
			LogMsg "Test Completed. Result : $mcResult."
			$testResult = "PASS"
		}
		elseif ( $finalStatus -imatch "TestRunning")
		{
			LogMsg "Powershell backgroud job for test is completed but VM is reporting that test is still running. Please check $LogDir\orionConsoleLogs.txt"
			LogMsg "Contests of summary.log : $mcSummary"
			$testResult = "PASS"
		}
		LogMsg "Test result : $testResult"
		LogMsg "Test Completed"
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
return $result, $resultSummary
