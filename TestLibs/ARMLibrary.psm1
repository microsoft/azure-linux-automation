﻿Function CreateAllResourceGroupDeployments($setupType, $xmlConfig, $Distro)
{

    $resourceGroupCount = 0
    $xml = $xmlConfig
    LogMsg $setupType
    $setupTypeData = $xml.config.Azure.Deployment.$setupType
    $allsetupGroups = $setupTypeData
    if ($allsetupGroups.HostedService[0].Location -or $allsetupGroups.HostedService[0].AffinityGroup)
    {
        $isMultiple = 'True'
        $resourceGroupCount = 0
    }
    else
    {
        $isMultiple = 'False'
    }

    foreach ($newDistro in $xml.config.Azure.Deployment.Data.Distro)
    {

        if ($newDistro.Name -eq $Distro)
        {
            $osImage = $newDistro.OsImage
            $osVHD = $newDistro.OsVHD
        }
    }

    $location = $xml.config.Azure.General.Location
    $AffinityGroup = $xml.config.Azure.General.AffinityGroup

    foreach ($RG in $setupTypeData.HostedService )
    {
        $curtime = Get-Date
        $isServiceDeployed = "False"
        $retryDeployment = 0
        if ( $RG.Tag -ne $null )
        {
            $groupName = "ICA-RG-" + $RG.Tag + "-" + $Distro + "-" + $curtime.Month + "-" +  $curtime.Day  + "-" + $curtime.Hour + "-" + $curtime.Minute + "-" + $curtime.Second
        }
        else
        {
            $groupName = "ICA-RG-" + $setupType + "-" + $Distro + "-" + $curtime.Month + "-" +  $curtime.Day  + "-" + $curtime.Hour + "-" + $curtime.Minute + "-" + $curtime.Second
        }
        if($isMultiple -eq "True")
        {
            $groupName = $groupName + "-" + $resourceGroupCount
        }

        while (($isServiceDeployed -eq "False") -and ($retryDeployment -lt 5))
        {
            #$groupName = "ICA-RG-D1-U1410-7-20-17-0-38"
            LogMsg "Creating Resource Group : $groupName."
            LogMsg "Verifying that Resource group name is not in use."
            #$isServiceDeleted = DeleteResourceGroup -RGName $groupName
$isServiceDeleted = $true
            if ($isServiceDeleted)
            {    
                $isServiceCreated = CreateResourceGroup -RGName $groupName -location $location
$isServiceCreated = $true
                if ($isServiceCreated -eq "True")
                {
                    #$isCertAdded = AddCertificate -serviceName $groupName
$isCertAdded = "True"
                    if ($isCertAdded -eq "True")
                    {
                        #LogMsg "Certificate added successfully."
                        $azureDeployJSONFilePath = "$LogDir\$groupName.json"
                        $DeploymentCommand = GenerateAzureDeployJSONFile -RGName $groupName -osImage $osImage -osVHD $osVHD -RGXMLData $RG -Location $location -azuredeployJSONFilePath $azureDeployJSONFilePath
                        $DeploymentStartTime = (Get-Date)
                        $CreateRGDeployments = CreateResourceGroupDeployment -RGName $groupName -location $location -setupType $setupType -TemplateFile $azureDeployJSONFilePath
                        $DeploymentEndTime = (Get-Date)
                        $DeploymentElapsedTime = $DeploymentEndTime - $DeploymentStartTime
                        if ( $CreateRGDeployments )
                        {
                            $retValue = "True"
                            $isServiceDeployed = "True"
                            $resourceGroupCount = $resourceGroupCount + 1
                            if ($resourceGroupCount -eq 1)
                            {
                                $deployedGroups = $groupName
                            }
                            else
                            {
                                $deployedGroups = $deployedGroups + "^" + $groupName
                            }

                        }
                        else
                        {
                            LogErr "Unable to Deploy one or more VM's"
                            $retryDeployment = $retryDeployment + 1
                            $retValue = "False"
                            $isServiceDeployed = "False"
                        }
                    }
                    else
                    {
                        LogErr "Unable to Add certificate to $groupName"
                        $retryDeployment = $retryDeployment + 1
                        $retValue = "False"
                        $isServiceDeployed = "False"
                    }

                }
                else
                {
                    LogErr "Unable to create $groupName"
                    $retryDeployment = $retryDeployment + 1
                    $retValue = "False"
                    $isServiceDeployed = "False"
                }
            }    
            else
            {
                LogErr "Unable to delete existing resource group - $groupName"
                $retryDeployment = 3
                $retValue = "False"
                $isServiceDeployed = "False"
            }
        }
    }
    return $retValue, $deployedGroups, $resourceGroupCount, $DeploymentElapsedTime
}

Function DeleteResourceGroup([string]$RGName, [switch]$KeepDisks)
{
    $ResourceGroup = Get-AzureResourceGroup -Name $RGName -ErrorAction Ignore
    if ($ResourceGroup)
    {
        $retValue =  Remove-AzureResourceGroup -Name $RGName -Force -PassThru -Verbose
    }
    else
    {
        LogMsg "$RGName does not exists."
        $retValue = $true
    }
    return $retValue
}

Function CreateResourceGroup([string]$RGName, $location)
{
    $FailCounter = 0
    $retValue = "False"
    $ResourceGroupDeploymentName = $RGName + "-deployment"
    $azureDeployJSONFilePath = ".\temp\msjason\ssauto.json"

    While(($retValue -eq $false) -and ($FailCounter -lt 5))
    {
        try
        {
            $FailCounter++
            if($location)
            {
                LogMsg "Using location : $location"
                $createRG = New-AzureResourceGroup -Name $RGName -Location $location.Replace('"','') -Force -Verbose
            }
            $operationStatus = $createRG.ProvisioningState
            if ($operationStatus  -eq "Succeeded")
            {
                LogMsg "Resource Group $RGName Created."
                $retValue = $true
            }
            else 
            {
                LogErr "Failed to Resource Group $RGName."
                $retValue = $false
            }
        }
        catch
        {
            $retValue = $false
        }
    }
    return $retValue
}

Function CreateResourceGroupDeployment([string]$RGName, $location, $setupType, $TemplateFile)
{
    $FailCounter = 0
    $retValue = "False"
    $ResourceGroupDeploymentName = $RGName + "-deployment"
    $azureDeployJSONFilePath = ".\temp\msjason\ssauto.json"

    While(($retValue -eq $false) -and ($FailCounter -lt 5))
    {
        try
        {
            $FailCounter++
            if($location)
            {
                LogMsg "Creating Deployment using $TemplateFile ..."
                $createRGDeployment = New-AzureResourceGroupDeployment -Name $ResourceGroupDeploymentName -ResourceGroupName $RGName -TemplateFile $TemplateFile -Verbose
            }
            $operationStatus = $createRGDeployment.ProvisioningState
            if ($operationStatus  -eq "Succeeded")
            {
                LogMsg "Resource Group Deployment Created."
                $retValue = $true
            }
            else 
            {
                LogErr "Failed to Resource Group."
                $retValue = $false
            }
        }
        catch
        {
            $retValue = $false
        }
    }
    return $retValue
}


Function GenerateAzureDeployJSONFile ($RGName, $osImage, $osVHD, $RGXMLData, $Location, $azuredeployJSONFilePath)
{
$jsonFile = $azuredeployJSONFilePath
$StorageAccountName = $xml.config.Azure.General.StorageAccount
$role = 0
$HS = $RGXMLData
$setupType = $Setup
$totalVMs = 0
$totalHS = 0
$extensionCounter = 0
$vmCommands = @()
$vmCount = 0
 

$indents = @()
$indent = ""
$singleIndent = ""
$indents += $indent
$RGRandomNumber = $((Get-Random -Maximum 999999 -Minimum 100000))
$RGrandomWord = ([System.IO.Path]::GetRandomFileName() -replace '[^a-z]')
$dnsNameForPublicIP = $($RGName.ToLower() -replace '[^a-z0-9]')
$virtualNetworkName = "icavnet"
$nicName = "ICANIC" 

#Generate Single Indent
for($i =0; $i -lt 4; $i++)
{
    $singleIndent += " "
}

#Generate Indent Levels
for ($i =0; $i -lt 30; $i++)
{
    $indent += $singleIndent
    $indents += $indent
}

LogMsg "Generating Template : $azuredeployJSONFilePath"
#region Generate JSON file
Set-Content -Value "$($indents[0]){" -Path $jsonFile -Force
    Add-Content -Value "$($indents[1])^`$schema^: ^https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#^," -Path $jsonFile
    Add-Content -Value "$($indents[1])^contentVersion^: ^1.0.0.0^," -Path $jsonFile
    Add-Content -Value "$($indents[1])^parameters^: {}," -Path $jsonFile
    Add-Content -Value "$($indents[1])^variables^:" -Path $jsonFile
    Add-Content -Value "$($indents[1]){" -Path $jsonFile
        Add-Content -Value "$($indents[2])^StorageAccountName^: ^$StorageAccountName^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^dnsNameForPublicIP^: ^$dnsNameForPublicIP^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^adminUserName^: ^$user^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^adminPassword^: ^$($password.Replace('"',''))^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^location^: ^$($Location.Replace('"',''))^," -Path $jsonFile
        #Add-Content -Value "$($indents[2])^vmSize^: ^Basic_A1^," -Path $jsonFile
        $PublicIPName = $($RGName -replace '[^a-zA-Z]') + "PublicIP"
        Add-Content -Value "$($indents[2])^publicIPAddressName^: ^$PublicIPName^," -Path $jsonFile
        #Add-Content -Value "$($indents[2])^vmName^: ^role0^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^virtualNetworkName^: ^$virtualNetworkName^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^nicName^: ^$nicName^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^addressPrefix^: ^10.0.0.0/16^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^vmSourceImageName^ : ^$osImage^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^CompliedSourceImageName^ : ^[concat('/',subscription().subscriptionId,'/services/images/',variables('vmSourceImageName'))]^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^subnet1Name^: ^Subnet-1^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^subnet2Name^: ^Subnet-2^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^subnet1Prefix^: ^10.0.0.0/24^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^subnet2Prefix^: ^10.0.1.0/24^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^vmStorageAccountContainerName^: ^vhds^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^publicIPAddressType^: ^Dynamic^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^storageAccountType^: ^Standard_LRS^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^vnetID^: ^[resourceId('Microsoft.Network/virtualNetworks',variables('virtualNetworkName'))]^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^subnet1Ref^: ^[concat(variables('vnetID'),'/subnets/',variables('subnet1Name'))]^," -Path $jsonFile
        Add-Content -Value "$($indents[2])^subnet2Ref^: ^[concat(variables('vnetID'),'/subnets/',variables('subnet2Name'))]^" -Path $jsonFile
        #Add more variables here, if required..
        #Add more variables here, if required..
        #Add more variables here, if required..
        #Add more variables here, if required..
    Add-Content -Value "$($indents[1])}," -Path $jsonFile
    LogMsg "Added Variables.."
    #region Define Resources
    
    Add-Content -Value "$($indents[1])^resources^:" -Path $jsonFile
    Add-Content -Value "$($indents[1])[" -Path $jsonFile

    #region Common Resources for all deployments..
        <##region StorageAccount
        Add-Content -Value "$($indents[2]){" -Path $jsonFile
            Add-Content -Value "$($indents[3])^type^: ^Microsoft.Storage/storageAccounts^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^name^: ^[variables('newStorageAccountName')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^apiVersion^: ^2015-05-01-preview^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^location^: ^[variables('location')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^properties^:" -Path $jsonFile
            Add-Content -Value "$($indents[3]){" -Path $jsonFile
                Add-Content -Value "$($indents[4])^accountType^: ^[variables('storageAccountType')]^" -Path $jsonFile
            Add-Content -Value "$($indents[3])}" -Path $jsonFile
        Add-Content -Value "$($indents[2])}," -Path $jsonFile
        #endregion#>

        #region publicIPAddresses
        Add-Content -Value "$($indents[2]){" -Path $jsonFile
            Add-Content -Value "$($indents[3])^apiVersion^: ^2015-05-01-preview^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^type^: ^Microsoft.Network/publicIPAddresses^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^name^: ^[variables('publicIPAddressName')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^location^: ^[variables('location')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^properties^:" -Path $jsonFile
            Add-Content -Value "$($indents[3]){" -Path $jsonFile
                Add-Content -Value "$($indents[4])^publicIPAllocationMethod^: ^[variables('publicIPAddressType')]^," -Path $jsonFile
                Add-Content -Value "$($indents[4])^dnsSettings^: " -Path $jsonFile
                Add-Content -Value "$($indents[4]){" -Path $jsonFile
                    Add-Content -Value "$($indents[5])^domainNameLabel^: ^[variables('dnsNameForPublicIP')]^" -Path $jsonFile
                Add-Content -Value "$($indents[4])}" -Path $jsonFile
            Add-Content -Value "$($indents[3])}" -Path $jsonFile
        Add-Content -Value "$($indents[2])}," -Path $jsonFile
        LogMsg "Added Public IP Address $PublicIPName.."
        #endregion

        #region virtualNetworks
        Add-Content -Value "$($indents[2]){" -Path $jsonFile
            Add-Content -Value "$($indents[3])^apiVersion^: ^2015-05-01-preview^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^type^: ^Microsoft.Network/virtualNetworks^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^name^: ^[variables('virtualNetworkName')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^location^: ^[variables('location')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^properties^:" -Path $jsonFile
            Add-Content -Value "$($indents[3]){" -Path $jsonFile
                #AddressSpace
                Add-Content -Value "$($indents[4])^addressSpace^: " -Path $jsonFile
                Add-Content -Value "$($indents[4]){" -Path $jsonFile
                    Add-Content -Value "$($indents[5])^addressPrefixes^: " -Path $jsonFile
                    Add-Content -Value "$($indents[5])[" -Path $jsonFile
                        Add-Content -Value "$($indents[6])^[variables('addressPrefix')]^" -Path $jsonFile
                    Add-Content -Value "$($indents[5])]" -Path $jsonFile
                Add-Content -Value "$($indents[4])}," -Path $jsonFile
                #Subnets
                Add-Content -Value "$($indents[4])^subnets^: " -Path $jsonFile
                Add-Content -Value "$($indents[4])[" -Path $jsonFile
                    Add-Content -Value "$($indents[5]){" -Path $jsonFile
                        Add-Content -Value "$($indents[6])^name^: ^[variables('subnet1Name')]^," -Path $jsonFile
                        Add-Content -Value "$($indents[6])^properties^: " -Path $jsonFile
                        Add-Content -Value "$($indents[6]){" -Path $jsonFile
                            Add-Content -Value "$($indents[7])^addressPrefix^: ^[variables('subnet1Prefix')]^" -Path $jsonFile
                        Add-Content -Value "$($indents[6])}" -Path $jsonFile
                    Add-Content -Value "$($indents[5])}," -Path $jsonFile
                    Add-Content -Value "$($indents[5]){" -Path $jsonFile
                        Add-Content -Value "$($indents[6])^name^: ^[variables('subnet2Name')]^," -Path $jsonFile
                        Add-Content -Value "$($indents[6])^properties^: " -Path $jsonFile
                        Add-Content -Value "$($indents[6]){" -Path $jsonFile
                            Add-Content -Value "$($indents[7])^addressPrefix^: ^[variables('subnet2Prefix')]^" -Path $jsonFile
                        Add-Content -Value "$($indents[6])}" -Path $jsonFile
                    Add-Content -Value "$($indents[5])}" -Path $jsonFile
                Add-Content -Value "$($indents[4])]" -Path $jsonFile
            Add-Content -Value "$($indents[3])}" -Path $jsonFile
        Add-Content -Value "$($indents[2])}," -Path $jsonFile
        LogMsg "Added Virtual Network $VnetName.."
        #endregion

        #region networkInterfaces
        Add-Content -Value "$($indents[2]){" -Path $jsonFile
            Add-Content -Value "$($indents[3])^apiVersion^: ^2015-05-01-preview^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^type^: ^Microsoft.Network/networkInterfaces^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^name^: ^[variables('nicName')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^location^: ^[variables('location')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^dependsOn^: " -Path $jsonFile
            Add-Content -Value "$($indents[3])[" -Path $jsonFile
                Add-Content -Value "$($indents[4])^[concat('Microsoft.Network/publicIPAddresses/', variables('publicIPAddressName'))]^," -Path $jsonFile
                Add-Content -Value "$($indents[4])^[concat('Microsoft.Network/virtualNetworks/', variables('virtualNetworkName'))]^" -Path $jsonFile
            Add-Content -Value "$($indents[3])]," -Path $jsonFile

            Add-Content -Value "$($indents[3])^properties^:" -Path $jsonFile
            Add-Content -Value "$($indents[3]){" -Path $jsonFile
                Add-Content -Value "$($indents[4])^ipConfigurations^: " -Path $jsonFile
                Add-Content -Value "$($indents[4])[" -Path $jsonFile
                    Add-Content -Value "$($indents[5]){" -Path $jsonFile
                        Add-Content -Value "$($indents[6])^name^: ^ipconfig1^," -Path $jsonFile
                        Add-Content -Value "$($indents[6])^properties^: " -Path $jsonFile
                        Add-Content -Value "$($indents[6]){" -Path $jsonFile
                            Add-Content -Value "$($indents[7])^privateIPAllocationMethod^: ^Dynamic^," -Path $jsonFile
                            Add-Content -Value "$($indents[7])^publicIPAddress^:" -Path $jsonFile
                            Add-Content -Value "$($indents[7]){" -Path $jsonFile
                                Add-Content -Value "$($indents[8])^id^: ^[resourceId('Microsoft.Network/publicIPAddresses',variables('publicIPAddressName'))]^" -Path $jsonFile
                            Add-Content -Value "$($indents[7])}," -Path $jsonFile
                            Add-Content -Value "$($indents[7])^subnet^:" -Path $jsonFile
                            Add-Content -Value "$($indents[7]){" -Path $jsonFile
                                Add-Content -Value "$($indents[8])^id^: ^[variables('subnet1Ref')]^" -Path $jsonFile
                            Add-Content -Value "$($indents[7])}" -Path $jsonFile
                        Add-Content -Value "$($indents[6])}" -Path $jsonFile
                    Add-Content -Value "$($indents[5])}" -Path $jsonFile
                Add-Content -Value "$($indents[4])]" -Path $jsonFile
            Add-Content -Value "$($indents[3])}" -Path $jsonFile
        Add-Content -Value "$($indents[2])}," -Path $jsonFile
        LogMsg "Added NIC $nicName.."
        #endregion
    $vmAdded = $false
    $role = 0
foreach ( $newVM in $RGXMLData.VirtualMachine)
{
    $vmCount = $vmCount + 1
    $VnetName = $RGXMLData.VnetName
    $instanceSize = $newVM.InstanceSize
    $SubnetName = $newVM.SubnetName
    $DnsServerIP = $RGXMLData.DnsServerIP
    if($newVM.RoleName)
    {
        $vmName = $newVM.RoleName
    }
    else
    {
        $vmName = $RGName+"-role-"+$role
    }

        
        #region virtualMachines
        
        if ( $vmAdded )
        {
            Add-Content -Value "$($indents[2])," -Path $jsonFile
        }
        Add-Content -Value "$($indents[2]){" -Path $jsonFile
            Add-Content -Value "$($indents[3])^apiVersion^: ^2015-05-01-preview^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^type^: ^Microsoft.Compute/virtualMachines^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^name^: ^$vmName^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^location^: ^[variables('location')]^," -Path $jsonFile
            Add-Content -Value "$($indents[3])^dependsOn^: " -Path $jsonFile
            Add-Content -Value "$($indents[3])[" -Path $jsonFile
                #Add-Content -Value "$($indents[4])^[concat('Microsoft.Storage/storageAccounts/', variables('newStorageAccountName'))]^," -Path $jsonFile
                Add-Content -Value "$($indents[4])^[concat('Microsoft.Network/networkInterfaces/', variables('nicName'))]^" -Path $jsonFile
            Add-Content -Value "$($indents[3])]," -Path $jsonFile

            #region VM Properties
            Add-Content -Value "$($indents[3])^properties^:" -Path $jsonFile
            Add-Content -Value "$($indents[3]){" -Path $jsonFile
                #region Hardware Profile
                Add-Content -Value "$($indents[4])^hardwareProfile^: " -Path $jsonFile
                Add-Content -Value "$($indents[4]){" -Path $jsonFile
                    Add-Content -Value "$($indents[5])^vmSize^: ^$instanceSize^" -Path $jsonFile
                Add-Content -Value "$($indents[4])}," -Path $jsonFile
                #endregion

                #region OSProfie
                Add-Content -Value "$($indents[4])^osProfile^: " -Path $jsonFile
                Add-Content -Value "$($indents[4]){" -Path $jsonFile
                    Add-Content -Value "$($indents[5])^computername^: ^$vmName^," -Path $jsonFile
                    Add-Content -Value "$($indents[5])^adminUsername^: ^[variables('adminUserName')]^," -Path $jsonFile
                    Add-Content -Value "$($indents[5])^adminPassword^: ^[variables('adminPassword')]^" -Path $jsonFile
                Add-Content -Value "$($indents[4])}," -Path $jsonFile
                #endregion

                #region Storage Profile
                Add-Content -Value "$($indents[4])^storageProfile^: " -Path $jsonFile
                Add-Content -Value "$($indents[4]){" -Path $jsonFile
                    Add-Content -Value "$($indents[5])^osDisk^ : " -Path $jsonFile
                    Add-Content -Value "$($indents[5]){" -Path $jsonFile
                        if ( $osVHD )
                        {
                            if ( $osImage)
                            {
                                LogMsg "Overriding ImageName with user provided VHD."
                            }
                            LogMsg "Using VHD : $osVHD"
                            Add-Content -Value "$($indents[5])^image^: " -Path $jsonFile
                            Add-Content -Value "$($indents[5]){" -Path $jsonFile
                                Add-Content -Value "$($indents[6])^uri^: ^[concat('http://',variables('StorageAccountName'),'.blob.core.windows.net/vhds/','$osVHD')]^" -Path $jsonFile
                            Add-Content -Value "$($indents[5])}," -Path $jsonFile
                            Add-Content -Value "$($indents[5])^osType^: ^Linux^," -Path $jsonFile
                        }
                        else
                        {
                            LogMsg "Using ImageName : $osImage"
                            Add-Content -Value "$($indents[5])^sourceImage^: " -Path $jsonFile
                            Add-Content -Value "$($indents[5]){" -Path $jsonFile
                                Add-Content -Value "$($indents[6])^id^: ^[variables('CompliedSourceImageName')]^" -Path $jsonFile
                            Add-Content -Value "$($indents[5])}," -Path $jsonFile
                        }
                        Add-Content -Value "$($indents[6])^name^: ^$vmName-OSDisk^," -Path $jsonFile
                        #Add-Content -Value "$($indents[6])^osType^: ^Linux^," -Path $jsonFile
                        Add-Content -Value "$($indents[6])^vhd^: " -Path $jsonFile
                        Add-Content -Value "$($indents[6]){" -Path $jsonFile
                            Add-Content -Value "$($indents[7])^uri^: ^[concat('http://',variables('StorageAccountName'),'.blob.core.windows.net/vhds/','$vmName-osdisk.vhd')]^" -Path $jsonFile
                        Add-Content -Value "$($indents[6])}," -Path $jsonFile
                        Add-Content -Value "$($indents[6])^caching^: ^ReadWrite^," -Path $jsonFile
                        Add-Content -Value "$($indents[6])^createOption^: ^FromImage^" -Path $jsonFile
                    Add-Content -Value "$($indents[5])}" -Path $jsonFile
                Add-Content -Value "$($indents[4])}," -Path $jsonFile
                LogMsg "Added Virtual Machine $vmName"
                #endregion

                #region Network Profile
                Add-Content -Value "$($indents[4])^networkProfile^: " -Path $jsonFile
                Add-Content -Value "$($indents[4]){" -Path $jsonFile
                    Add-Content -Value "$($indents[5])^networkInterfaces^: " -Path $jsonFile
                    Add-Content -Value "$($indents[5])[" -Path $jsonFile
                        Add-Content -Value "$($indents[6]){" -Path $jsonFile
                            Add-Content -Value "$($indents[7])^id^: ^[resourceId('Microsoft.Network/networkInterfaces',variables('nicName'))]^" -Path $jsonFile
                        Add-Content -Value "$($indents[6])}" -Path $jsonFile
                    Add-Content -Value "$($indents[5])]," -Path $jsonFile
                    Add-Content -Value "$($indents[5])^inputEndpoints^: " -Path $jsonFile
                    Add-Content -Value "$($indents[5])[" -Path $jsonFile
                    
                    #region Add Endpoints...
                    $EndPointAdded = $false
                    foreach ( $openedPort in $newVM.EndPoints)
                    {
                        if ( $EndPointAdded )
                        {
                            Add-Content -Value "$($indents[6])," -Path $jsonFile            
                        }
                        Add-Content -Value "$($indents[6]){" -Path $jsonFile
                            Add-Content -Value "$($indents[7])^enableDirectServerReturn^: ^False^," -Path $jsonFile
                            Add-Content -Value "$($indents[7])^endpointName^: ^SSH^," -Path $jsonFile
                            Add-Content -Value "$($indents[7])^privatePort^: 22," -Path $jsonFile
                            Add-Content -Value "$($indents[7])^publicPort^: 22," -Path $jsonFile
                            Add-Content -Value "$($indents[7])^protocol^: ^tcp^" -Path $jsonFile
                        Add-Content -Value "$($indents[6])}" -Path $jsonFile            
                        $EndPointAdded = $true
                    }
                    #endregion 

                    Add-Content -Value "$($indents[5])]" -Path $jsonFile
                Add-Content -Value "$($indents[4])}" -Path $jsonFile
                #endregion

            Add-Content -Value "$($indents[3])}" -Path $jsonFile
            LogMsg "Added Network Profile."
            #endregion

        Add-Content -Value "$($indents[2])}" -Path $jsonFile
        #endregion
}
    Add-Content -Value "$($indents[1])]" -Path $jsonFile
Add-Content -Value "$($indents[0])}" -Path $jsonFile
Set-Content -Path $jsonFile -Value (Get-Content $jsonFile).Replace("^",'"') -Force
#endregion
LogMsg "Template generated successfully."
    return $createSetupCommand,  $RGName, $vmCount
} 


Function DeployResourceGroups ($xmlConfig, $setupType, $Distro, $getLogsIfFailed = $false, $GetDeploymentStatistics = $false)
{
    if( (!$EconomyMode) -or ( $EconomyMode -and ($xmlConfig.config.Azure.Deployment.$setupType.isDeployed -eq "NO")))
    {
        try
        {
            $VerifiedGroups =  $NULL
            $retValue = $NULL
            $ExistingGroups = Get-AzureResourceGroup
            $i = 0
            $role = 1
            $setupTypeData = $xmlConfig.config.Azure.Deployment.$setupType
            $isAllDeployed = CreateAllResourceGroupDeployments -setupType $setupType -xmlConfig $xmlConfig -Distro $Distro
            #$isAllDeployed = CreateAllDeployments -xmlConfig $xmlConfig -setupType $setupType -Distro $Distro
            $isAllVerified = "False"
            $isAllConnected = "False"
            if($isAllDeployed[0] -eq "True")
            {
                $deployedGroups = $isAllDeployed[1]
                $resourceGroupCount = $isAllDeployed[2]
                $DeploymentElapsedTime = $isAllDeployed[3]
                $GroupsToVerify = $deployedGroups.Split('^') ########
                #if ( $GetDeploymentStatistics )
                #{
                #    $VMBooTime = GetVMBootTime -DeployedGroups $deployedGroups -TimeoutInSeconds 1800
                #    $verifyAll = VerifyAllDeployments -GroupsToVerify $GroupsToVerify -GetVMProvisionTime $GetDeploymentStatistics
                #    $isAllVerified = $verifyAll[0]
                #    $VMProvisionTime = $verifyAll[1]
                #}
                #else
                #{
                #    $isAllVerified = VerifyAllDeployments -GroupsToVerify $GroupsToVerify
                #}
                #if ($isAllVerified -eq "True")
                #{
                    $allVMData = GetAllDeployementData -ResourceGroups $deployedGroups
                    $isAllConnected = isAllSSHPortsEnabledRG -AllVMDataObject $allVMData
                    if ($isAllConnected -eq "True")
                    {
            #Set-Content .\temp\DeployedGroupsFile.txt "$deployedGroups"
                        $VerifiedGroups = $deployedGroups
                        $retValue = $VerifiedGroups
                    #    $vnetIsAllConfigured = $false
                        $xmlConfig.config.Azure.Deployment.$setupType.isDeployed = $retValue
                    #Collecting Initial Kernel
                    #    $user=$xmlConfig.config.Azure.Deployment.Data.UserName
                        $KernelLogOutput= GetAndCheckKernelLogs -DeployedGroups $deployedGroups -status "Initial"
                    }
                    else
                    {
                        LogErr "Unable to connect Some/All SSH ports.."
                        $retValue = $NULL  
                    }
                #}
                #else
                #{
                #    Write-Host "Provision Failed for one or more VMs"
                #    $retValue = $NULL
                #}
                
            }
            else
            {
                LogErr "One or More Deployments are Failed..!"
                $retValue = $NULL
            }
            # get the logs of the first provision-failed VM
            #if ($retValue -eq $NULL -and $getLogsIfFailed -and $DebugOsImage)
            #{
            #    foreach ($service in $GroupsToVerify)
            #    {
            #        $VMs = Get-AzureVM -ServiceName $service
            #        foreach ($vm in $VMs)
            #        {
            #            if ($vm.InstanceStatus -ne "ReadyRole" )
            #            {
            #                $out = GetLogsFromProvisionFailedVM -vmName $vm.Name -serviceName $service -xmlConfig $xmlConfig
            #                return $NULL
            #            }
            #        }
            #    }
            #}
        }
        catch
        {
            LogMsg "Exception detected. Source : DeployVMs()"
            $retValue = $NULL
        }
    }
    else
    {
        $retValue = $xmlConfig.config.Azure.Deployment.$setupType.isDeployed
        $KernelLogOutput= GetAndCheckKernelLogs -DeployedGroups $retValue -status "Initial"
    }
    
    if ( $GetDeploymentStatistics )
    {
        return $retValue, $DeploymentElapsedTime, $VMBooTime, $VMProvisionTime
    }
    else
    {
        return $retValue
    }
}

Function isAllSSHPortsEnabledRG($AllVMDataObject)
{
    LogMsg "Trying to Connect to deployed VM(s)"
    $timeout = 0
    do
    {
        $WaitingForConnect = 0
        foreach ( $vm in $AllVMDataObject)
        {
            Write-Host "Connecting to  $($vm.PublicIP) : $($vm.SSHPort)" -NoNewline
            $out = Test-TCP  -testIP $($vm.PublicIP) -testport $($vm.SSHPort)
            if ($out -ne "True")
            { 
                Write-Host " : Failed"
                $WaitingForConnect = $WaitingForConnect + 1
            }
            else
            {
                Write-Host " : Connected"
            }
        }
        if($WaitingForConnect -gt 0)
        {
            $timeout = $timeout + 1
            Write-Host "$WaitingForConnect VM(s) still awaiting to open SSH port.." -NoNewline
            Write-Host "Retry $timeout/100"
            sleep 3
            $retValue = "False"
        }
        else
        {
            LogMsg "ALL VM's SSH port is/are open now.."
            $retValue = "True"
        }

    }
    While (($timeout -lt 100) -and ($WaitingForConnect -gt 0))

    return $retValue
}