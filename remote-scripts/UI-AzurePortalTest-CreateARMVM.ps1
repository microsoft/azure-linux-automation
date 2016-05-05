<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

try
{
	#update test config file
	$ConfigFile = "$PWD\AzureUIAutomation\Config.xml"
	[xml]$ConfigXML = Get-Content $ConfigFile
	$ConfigXML.Settings.Location = $xmlConfig.config.Azure.General.Location.Trim('"')
	$ConfigXML.Settings.UserName = $user
	$ConfigXML.Settings.Password = $password
	$ConfigXML.Settings.ImageLabel = $currentTestData.Parameters.ImageLabel
	$ConfigXML.Settings.Size = $currentTestData.Parameters.VMsize
	$ConfigXML.Save($ConfigFile)
	#Clear all IE Cached Data
	RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 255
	cd AzureUIAutomation
	if(Test-Path testResult.xml)
	{
		Remove-Item testResult.xml
	}
	#You need set the path of 'mstest.exe' into Environment Variables of Windows Slave
	MSTest.exe /testcontainer:OSTCPortalTesting.dll /resultsfile:testResult.xml	
	[xml]$ResultXml = Get-Content .\testResult.xml
	cd ..
	Copy-Item .\AzureUIAutomation\testResult.xml $LogDir
	$Resultsummary = $ResultXml.TestRun.ResultSummary.Counters
	if($Resultsummary.total -eq $Resultsummary.passed)
	{		
		$testResult = "PASS"
	}
	else
	{
		$testResult = "FAIL"	
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

$result = GetFinalResultHeader -resultarr $resultArr

return $result