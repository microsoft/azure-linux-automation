<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

try
{
	$setuptype = $currentTestData.setupType
	$templateName = $currentTestData.TemplateName
	$setupTypeData = $xmlConfig.config.Azure.Deployment.$setupType
	$parameters = $xmlConfig.config.Azure.Deployment.$setupType.$templateName.parameters
	$location = $xmlConfig.config.Azure.General.Location

	if(Test-Path .\azuredeploy.parameters.json)
	{
		Remove-Item .\azuredeploy.parameters.json
	}

	# update template parameter file 
	LogMsg 'update template parameter file '
	$jsonfile =  Get-Content ..\azure-quickstart-templates\cloudera-on-centos\azuredeploy.parameters.json -Raw | ConvertFrom-Json
	$curtime = Get-Date
	$timestr = "-" + $curtime.Month + "-" +  $curtime.Day  + "-" + $curtime.Hour + "-" + $curtime.Minute + "-" + $curtime.Second
	$jsonfile.storageAccountPrefix.value = $parameters.storageAccountPrefix + $curtime.Month + $curtime.Day + $curtime.Hour + $curtime.Minute + $curtime.Second
	$jsonfile.dnsNamePrefix.value = $parameters.dnsNamePrefix + $timestr
	$jsonfile.virtualNetworkName.value = $parameters.virtualNetworkName + $timestr
	$jsonfile.subnetName.value = $parameters.subnetName + $timestr
	$jsonfile.numberOfDataNodes.value = [int]$parameters.numberOfDataNodes
	$jsonfile.adminPassword.value = $password.Replace('"','')
	$jsonfile.cmPassword.value = $password.Replace('"','')
	$jsonfile.location.value = $location.Replace('"','').Replace(' ','').ToLower()
	$jsonfile.vmSize.value = $parameters.vmSize
	$jsonfile.company.value = $parameters.company
	$jsonfile.emailAddress.value = $parameters.emailAddress
	$jsonfile.firstName.value = $parameters.firstName
	$jsonfile.lastName.value = $parameters.lastName
	if($env:RoleInstanceSize)
	{
		$jsonfile.vmSize.value = $env:RoleInstanceSize
	}
	if($jsonfile.vmSize.value -match 'DS' -or $jsonfile.vmSize.value -match 'DS')
	{
		$jsonfile.storageAccountType.value = 'Premium_LRS'
	}
	else
	{
		$jsonfile.storageAccountType.value = 'Standard_LRS'
	}
	# save template parameter file
	$jsonfile | ConvertTo-Json | Out-File .\azuredeploy.parameters.json

	if(Test-Path .\azuredeploy.parameters.json)
	{
		LogMsg "successful save azuredeploy.parameters.json"
	}
	else
	{
		LogMsg "fail to save azuredeploy.parameters.json"
	}

	$isDeployed = CreateAllRGDeploymentsWithTempParameters -setupType $setupType -templateName $templateName -location $location -TemplateFile ..\azure-quickstart-templates\cloudera-on-centos\azuredeploy.json  -TemplateParameterFile .\azuredeploy.parameters.json


	if ($isDeployed[0] -eq $True)
	{
		$testResult = "PASS"
	}
	else
	{
		$testResult = "Failed"
	}
	
	$testStatus = "TestCompleted"
	LogMsg "Test result : $testResult"

	if ($testStatus -eq "TestCompleted")
	{
		LogMsg "Test Completed"
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

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed[1] -ResourceGroups $isDeployed[1]

#Return the result and summery to the test suite script..
return $result
