param($xmlConfig)
if ( $UseAzureResourceManager )
{
    $storageAccountName =  $xmlConfig.config.Azure.General.ARMStorageAccount
    $StorageAccounts = Get-AzureStorageAccount
    foreach ($SA in $StorageAccounts)
    {
        if ( $SA.Name -eq $storageAccountName )
        {
            LogMsg "Getting $storageAccountName storage account key..."
            $storageAccountKey = (Get-AzureStorageAccountKey -ResourceGroupName $SA.ResourceGroupName -Name $SA.Name).Key1
        }
    }
}
else
{
    $storageAccountName =  $xmlConfig.config.Azure.General.StorageAccount
    LogMsg "Getting $storageAccountName storage account key..."
    $storageAccountKey = (Get-AzureStorageKey -StorageAccountName $storageAccountName).Primary
}
return $storageAccountKey