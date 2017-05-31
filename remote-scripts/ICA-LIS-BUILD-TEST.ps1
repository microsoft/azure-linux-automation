# This script deploys the VMs for the LIS-BUILD functional test and trigger the test based on given TESTIDs.
# 1. dos2unix, tar, , wge must be installed in the test image
# 2. It requires the current & previous LIS builds at specified location mentioned in the test definition
#
# Author: Sivakanth Rebba
# Email: v-sirebb@microsoft.com
#
###################################################################################

<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force

$Subtests = $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
$LISVersion = ""
$PreviousLISExtractCommand = $currentTestData.PreviousLISExtractCommand
$CurrentLISExtractCommand = $currentTestData.CurrentLISExtractCommand
$LISExtractCommand = ""
$result = ""
$testResult = ""
$resultArr = @()

Function CreateTestVMNode
{
	param(
            [string] $ServiceName,
			[string] $VIP,
			[string] $SSHPort,
			[string]  $username,
			[string] $password,
			[string] $DIP,
			[string] $DNSUrl,
			[string] $logDir )


	$objNode = New-Object -TypeName PSObject
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name ServiceName -Value $ServiceName -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name VIP -Value $VIP -Force 
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name SSHPort -Value $SSHPort -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name username -Value  $username -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name password -Value $password -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name DIP -Value $nodeDip -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name logDir -Value $LogDir -Force
	Add-Member -InputObject $objNode -MemberType NoteProperty -Name DNSURL -Value $DNSUrl -Force
	return $objNode
}

Function GetVMBasicInfo($VMObject, $PrevTestStatus, $metaData)
{
    if ( $PrevTestStatus -eq "PASS" )
    {
		LogMsg "STARTING TEST : $metaData"
		Set-Content -Value "**************modinfo hv_vmbus $metaData installing LIS******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
        $modinfo_hv_vmbus_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $modinfo_hv_vmbus_status -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
		Set-Content -Value "**************lsmod | egrep 'hv|hyper' $metaData installing LIS******************" -Path "$($VMObject.logDir)\lsmod_hv_module_status.txt"
        $lsmod_hv_modules_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $lsmod_hv_modules_status -Path "$($VMObject.logDir)\lsmod_hv_module_status.txt"
		
		$BasicInfoCmds = "date^last^uname -r^uname -a^modinfo hv_vmbus^modinfo hv_storvsc^cat /etc/*-release^df -hT^fdisk -l^cat /etc/fstab^hostname^ll `/`boot^python -V^waagent --version^lsmod | egrep 'hv|hyper'^pgrep -lf kvp^pgrep -lf fcopy^pgrep -lf vss"
		$BasicInfoCmds = ($BasicInfoCmds).Split("^")
		Set-Content -Value "**************$BasicInfoCmd $metaData installing LIS******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		foreach($BasicInfoCmd in $BasicInfoCmds)
		{
			$basic_VM_cmd_info_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $BasicInfoCmd -runAsSudo -ignoreLinuxExitCode
			Add-Content -Value $basic_VM_cmd_info_status -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		}
	
	}
	
}

Function InstallLIS($VMObject, $PrevTestStatus, $metaData, $ISAbortIgnore="No")
{
    if ( $PrevTestStatus -eq "PASS" )
    {
        LogMsg "STARTING TEST : $metaData"
        $LISExtractCommands = $LISExtractCommand.Split("^")
		$BasicInfoCmds = "date^last^uname -r^uname -a^modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils^cat /etc/*-release^df -hT^fdisk -l^cat /etc/fstab^hostname^python -V^waagent --version^lsmod | egrep 'hv|hyper'^pgrep -lf kvp^pgrep -lf fcopy^pgrep -lf vss"
		$BasicInfoCmds = ($BasicInfoCmds).Split("^")
		Set-Content -Value "**************$BasicInfoCmd $metaData******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		foreach($BasicInfoCmd in $BasicInfoCmds)
		{
			Add-Content -Value "************** Status of $BasicInfoCmd******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
			$basic_VM_cmd_info_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $BasicInfoCmd -runAsSudo -ignoreLinuxExitCode
			Add-Content -Value $basic_VM_cmd_info_status -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		}
        Set-Content -Value "**************modinfo hv_vmbus before installing LIS $LISVersion******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
        $modinfo_hv_vmbus_before_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $modinfo_hv_vmbus_before_installing_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
		Set-Content -Value "***************modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils before installing LIS $LISVersion******************" -Path "$($VMObject.logDir)\hv_modules_status.txt"
        $hv_modules_before_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $hv_modules_before_installing_LIS -Path "$($VMObject.logDir)\hv_modules_status.txt"
        foreach ( $LISExtractCommand in $LISExtractCommands )
        {
            $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $LISExtractCommand -runAsSudo
        }
        $installLISConsoleOutput = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "./install.sh" -runAsSudo -runMaxAllowedTime 1200 -ignoreLinuxExitCode 2>&1
        LogMsg "`n$installLISConsoleOutput"
		Set-Content -Value $installLISConsoleOutput -Path "$($VMObject.logDir)\InstallLISConsoleOutput.txt"
        if($installLISConsoleOutput -imatch "is already installed")
        {
            LogMsg "Latest LIS version is already installed."
            $ExitCode = "PASS"
        }
        else
        {
			if($installLISConsoleOutput -imatch "warning")
			{
				LogErr "LIS install is failed due to found warnings."
				$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\installLISConsoleOutput.txt" | Select-String "warning"
				LogMsg "$ErrorWarningStatus"
				Add-Content -Value "**************modinfo hv_vmbus after installing LIS $LISVersion******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
				$modinfo_hv_vmbus_after_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
				Add-Content -Value $modinfo_hv_vmbus_after_installing_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
				LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_installing_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_installing_LIS `n********************************************************"
				$ExitCode = "PASS"
			}
			elseif($installLISConsoleOutput -imatch "error")
			{
				LogErr "Latest LIS install is failed due to found errors."
				$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\installLISConsoleOutput.txt" | Select-String "error"
				LogMsg "$ErrorWarningStatus"
				$modinfo_hv_vmbus_after_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
				LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_installing_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_installing_LIS `n********************************************************"
				$ExitCode = "FAIL"
			}
			elseif($installLISConsoleOutput -imatch "abort")
			{
				
				if($ISAbortIgnore -imatch "YES")
				{
					LogMsg "Latest LIS install is Abort due to System is not rebooted after kernel upgrade."
					$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\installLISConsoleOutput.txt" | Select-String "abort"
					LogMsg "$ErrorWarningStatus"
					Add-Content -Value "**************modinfo hv_vmbus after installing LIS $LISVersion******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					$modinfo_hv_vmbus_after_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $modinfo_hv_vmbus_after_installing_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_installing_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_installing_LIS `n********************************************************"					
					$ExitCode = "PASS"
					
				}
				else
				{
					LogErr "Latest LIS install is failed due to lis build aborted."
					$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\installLISConsoleOutput.txt" | Select-String "abort"
					LogMsg "$ErrorWarningStatus"
					$modinfo_hv_vmbus_after_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
					LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_installing_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_installing_LIS `n********************************************************"
					$ExitCode = "FAIL"
				}
				
			}
			else
			{
				#Reboot VM..
				$restartStatus = RestartAllDeployments -allVMData $allVMData
				if ( $restartStatus -eq "True")
				{
					#Verify LIS Version
					Add-Content -Value "**************modinfo hv_vmbus after installing LIS $LISVersion******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					$modinfo_hv_vmbus_after_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $modinfo_hv_vmbus_after_installing_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					Set-Content -Value "***************modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils after installing LIS $LISVersion******************" -Path "$($VMObject.logDir)\hv_modules_status.txt"
					$hv_modules_after_installing_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $hv_modules_after_installing_LIS -Path "$($VMObject.logDir)\hv_modules_status.txt"
					if ( $modinfo_hv_vmbus_before_installing_LIS -ne $modinfo_hv_vmbus_after_installing_LIS )
					{
						LogMsg "New LIS version detected. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_installing_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_installing_LIS `n********************************************************"
						$ExitCode = "PASS"
					}
					else
					{
						LogErr "New LIS version NOT detected."
						$ExitCode = "FAIL"
					}
				}
				else
				{
					LogErr "VM is not accessible after reboot. Further Tests will be aborted."
					$ExitCode = "ABORTED"
				}
			}
        }
    }
    elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous Aborted test"
    }
return $ExitCode
}

Function UpgradeLIS($VMObject, $PrevTestStatus, $metaData)
{
    if ( $PrevTestStatus -eq "PASS" )
    {
        LogMsg "STARTING TEST : $metaData"
        $LISExtractCommands = $LISExtractCommand.Split("^")
        Set-Content -Value "**************modinfo hv_vmbus before upgrading LIS $LISVersion******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
        $modinfo_hv_vmbus_before_upgrading_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $modinfo_hv_vmbus_before_upgrading_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
		Set-Content -Value "***************modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils before upgrading LIS $LISVersion******************" -Path "$($VMObject.logDir)\hv_modules_status.txt"
        $hv_modules_before_upgrading_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $hv_modules_before_upgrading_LIS -Path "$($VMObject.logDir)\hv_modules_status.txt"
        foreach ( $LISExtractCommand in $LISExtractCommands )
        {
            $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $LISExtractCommand -runAsSudo
        }
        $upgradelLISConsoleOutput = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "./upgrade.sh" -runAsSudo -runMaxAllowedTime 1200
        Set-Content -Value $upgradelLISConsoleOutput -Path "$($VMObject.logDir)\UpgradeLISConsoleOutput.txt"
        if($upgradelLISConsoleOutput -imatch "is already installed")
        {
            LogMsg "Latest LIS version is already installed."
            $ExitCode = "PASS"
        }
        else
        {
            #Verification of Errors & Warnings in LIS installation process
			if($upgradelLISConsoleOutput -imatch "error" -or $upgradelLISConsoleOutput -imatch "warning" -or $upgradelLISConsoleOutput -imatch "abort")
			{
				LogErr "Latest LIS install is failed due found errors or warnings or aborted."
				$ExitCode = "FAIL"
			}
			else
			{
				#Reboot VM..
				$restartStatus = RestartAllDeployments -allVMData $allVMData
				if ( $restartStatus -eq "True")
				{
					#Verify LIS Version
					Add-Content -Value "**************modinfo hv_vmbus after upgrading LIS $LISVersion******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					$modinfo_hv_vmbus_after_upgrading_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $modinfo_hv_vmbus_after_upgrading_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					Add-Content -Value "***************modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils after upgrading LIS $LISVersion******************" -Path "$($VMObject.logDir)\hv_modules_status.txt"
					$hv_modules_after_upgrading_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $hv_modules_after_upgrading_LIS -Path "$($VMObject.logDir)\hv_modules_status.txt"
					if ( $modinfo_hv_vmbus_before_upgrading_LIS -ne $modinfo_hv_vmbus_after_upgrading_LIS )
					{
						LogMsg "New upgraded LIS version detected. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_upgrading_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_upgrading_LIS `n********************************************************"
						$ExitCode = "PASS"
					}
					else
					{
						LogErr "New LIS version NOT detected."
						$ExitCode = "FAIL"
					}
				}
				else
				{
					LogErr "VM is not accessible after reboot. Further Tests will be aborted."
					$ExitCode = "ABORTED"
				}
			}
        }
    }
    elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous Aborted test"
    }
return $ExitCode
}


Function UninstallLIS($VMObject, $PrevTestStatus, $metaData)
{
    if ( $PrevTestStatus -eq "PASS" )
    {
        LogMsg "STARTING TEST : $metaData"
        Set-Content -Value "**************modinfo hv_vmbus before uninstalling LIS******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
        $modinfo_hv_vmbus_before_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $modinfo_hv_vmbus_before_uninstalling_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
		Set-Content -Value "***************modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils before uninstalling LIS $LISVersion******************" -Path "$($VMObject.logDir)\hv_modules_status.txt"
        $hv_modules_before_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils" -runAsSudo -ignoreLinuxExitCode
        Add-Content -Value $hv_modules_before_uninstalling_LIS -Path "$($VMObject.logDir)\hv_modules_status.txt"
        Set-Content -Value "**************Microsoft HyperV lib modules before uninstalling LIS******************" -Path "$($VMObject.logDir)\microsoft_hyperv_lib_modules_status.txt"
		$isHypervModulesEmptyBeforeUninstall = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "ls /lib/modules/`$(uname -r)`/extra/microsoft-hyper-v" -runAsSudo -ignoreLinuxExitCode 2>&1
		Add-Content -Value $isHypervModulesEmptyBeforeUninstall -Path "$($VMObject.logDir)\microsoft_hyperv_lib_modules_status.txt"
		foreach ( $LISExtractCommand in $LISExtractCommands )
        {
            $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $LISExtractCommand -runAsSudo
        }
        $uninstallLISConsoleOutput = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "./uninstall.sh" -runAsSudo -runMaxAllowedTime 1200
        Set-Content -Value $uninstallLISConsoleOutput -Path "$($VMObject.logDir)\uninstallLISConsoleOutput.txt"
        if($uninstallLISConsoleOutput -imatch "No LIS RPM's are present")
        {
            LogMsg "LIS already uninstalled and It has Inbuilt LIS drivers"
            $ExitCode = "PASS"
        }
        else
        {
            #Verification of Errors & Warnings in LIS installation process
			if($uninstallLISConsoleOutput -imatch "warning")
			{
				LogErr "LIS uninstall is failed due to found warnings."
				$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\uninstallLISConsoleOutput.txt" | Select-String "warning"
				LogMsg "$ErrorWarningStatus"
				$modinfo_hv_vmbus_after_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
				LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_uninstalling_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_uninstalling_LIS `n********************************************************"
				Add-Content -Value "**************Microsoft HyperV lib modules before uninstalling LIS******************" -Path "$($VMObject.logDir)\microsoft_hyperv_lib_modules_status.txt"
				$isHypervModulesEmptyAfterUninstall = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command 'ls /lib/modules/`$(uname -r)`/extra/microsoft-hyper-v 2>&1' -runAsSudo -ignoreLinuxExitCode 2>&1
				Add-Content -Value $isHypervModulesEmptyAfterUninstall -Path "$($VMObject.logDir)\microsoft_hyperv_lib_modules_status.txt"
				if ( ($modinfo_hv_vmbus_before_uninstalling_LIS -ne $modinfo_hv_vmbus_after_uninstalling_LIS ) -and ($isHypervModulesEmptyAfterUninstall -imatch "No such file or directory"))
				{
					LogMsg "Downgraded to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_uninstalling_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_uninstalling_LIS `n********************************************************"
					LogMsg "**************Microsoft HyperV lib midules are EMPTY ****************************"
					$ExitCode = "PASS"
				}
				else
				{
					LogErr "Uninstall LIS failed and Inbuilt LIS drivers NOT detected OR Microsoft HyperV lib midules are NOT EMPTY"
					$ExitCode = "FAIL"
				}
			}
			elseif($uninstallLISConsoleOutput -imatch "error")
			{
				LogErr "Latest LIS install is failed due to found errors."
				$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\uninstallLISConsoleOutput.txt" | Select-String "error"
				LogMsg "$ErrorWarningStatus"
				$modinfo_hv_vmbus_after_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
				LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_uninstalling_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_uninstalling_LIS `n********************************************************"
				$ExitCode = "FAIL"
			}
			elseif($uninstallLISConsoleOutput -imatch "abort")
			{
				LogErr "Latest LIS install is failed due to lis build aborted."
				$ErrorWarningStatus = Get-Content -Path "$($VMObject.logDir)\uninstallLISConsoleOutput.txt" | Select-String "abort"
				LogMsg "$ErrorWarningStatus"
				$modinfo_hv_vmbus_after_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
				LogMsg "Downgrade to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_uninstalling_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_uninstalling_LIS `n********************************************************"
				$ExitCode = "FAIL"
			}
			else
			{
				#Reboot VM..
				$restartStatus = RestartAllDeployments -allVMData $allVMData
				if ( $restartStatus -eq "True")
				{
					#Verify LIS Version
					Add-Content -Value "**************modinfo hv_vmbus after uninstalling LIS******************" -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					$modinfo_hv_vmbus_after_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $modinfo_hv_vmbus_after_uninstalling_LIS -Path "$($VMObject.logDir)\modinfo_hv_vmbus_status.txt"
					Add-Content -Value "***************modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils after uninstalling LIS $LISVersion******************" -Path "$($VMObject.logDir)\hv_modules_status.txt"
					$hv_modules_after_uninstalling_LIS = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $hv_modules_after_uninstalling_LIS -Path "$($VMObject.logDir)\hv_modules_status.txt"
					Add-Content -Value "**************Microsoft HyperV lib modules after uninstalling LIS******************" -Path "$($VMObject.logDir)\microsoft_hyperv_lib_modules_status.txt"
					$isHypervModulesEmptyAfterUninstall = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command 'ls /lib/modules/`$(uname -r)`/extra/microsoft-hyper-v 2>&1' -runAsSudo -ignoreLinuxExitCode 2>&1
					Add-Content -Value $isHypervModulesEmptyAfterUninstall -Path "$($VMObject.logDir)\microsoft_hyperv_lib_modules_status.txt"
					if ( ($modinfo_hv_vmbus_before_uninstalling_LIS -ne $modinfo_hv_vmbus_after_uninstalling_LIS ) -and ($isHypervModulesEmptyAfterUninstall -imatch "No such file or directory"))
					{
						LogMsg "Downgraded to Previous LIS version. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_uninstalling_LIS `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_uninstalling_LIS `n********************************************************"
						LogMsg "**************Microsoft HyperV lib midules are EMPTY ****************************"
						$ExitCode = "PASS"
					}
					else
					{
						LogErr "Uninstall LIS failed and Inbuilt LIS drivers NOT detected OR Microsoft HyperV lib midules are NOT EMPTY"
						$ExitCode = "FAIL"
					}
				}
				else
				{
					LogErr "VM is not accessible after reboot. Further Tests will be aborted."
					$ExitCode = "ABORTED"
				}
			}
        }
    }
    elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous Aborted test"
    }
return $ExitCode
}

Function isLinuxProcessRunning ($VMObject, $ProcessName)
{
    LogMsg "Verifying if $ProcessName is running.."
    $psef = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "ps -ef"
    $foundProcesses = 0
    foreach ( $line in $psef.Split("`n"))
    {
        if (( $line -imatch $ProcessName) -and !( $line -imatch "--color=auto"))
        {
            $foundProcesses += 1
            $linuxUID = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[0]
            $linuxPID = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[1]
            $linuxPPID = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[2]
            $linuxC = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[3]
            $linuxSTIME = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[4]
            $linuxTTY = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[5]
            $linuxTIME = $line.Trim().Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Split(" ")[6]
            $linuxCMD = $line.Trim().Replace("$linuxUID","").Replace("$linuxPID","").Replace("$linuxPPID","").Replace("$linuxC","").Replace("$linuxSTIME","").Replace("$linuxTTY","").Replace("$linuxTIME","").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ").Replace("  "," ")
            LogMsg "FOUND PROCESS : UID=$linuxUID, PID=$linuxPID, RUNNING TIME=$linuxTIME, COMMAND=$linuxCMD"
        }
    }
    return $foundProcesses
}

Function UpgradeKernel($VMObject, $PrevTestStatus, $metaData, $isReboot = "YES")
{
    if ( $PrevTestStatus -eq "PASS" )
    {
        LogMsg "Starting Test : $metaData"
		$BasicInfoCmds = "date^modinfo hv_vmbus hv_storvsc hv_netvsc hv_utils^cat /etc/*-release^uname -r^uname -a"
		$BasicInfoCmds = ($BasicInfoCmds).Split("^")
		Set-Content -Value "**************$BasicInfoCmd $metaData******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		foreach($BasicInfoCmd in $BasicInfoCmds)
		{
			Add-Content -Value "************** Status of $BasicInfoCmd******************" -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
			$basic_VM_cmd_info_status = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command $BasicInfoCmd -runAsSudo -ignoreLinuxExitCode
			Add-Content -Value $basic_VM_cmd_info_status -Path "$($VMObject.logDir)\basic_VM_info_status.txt"
		}
		Set-Content -Value "**************modinfo hv_vmbus before upgrading Kernel******************" -Path "$($VMObject.LogDir)\InfoBeforeKernelUpgrade.txt"
		$modinfo_hv_vmbus_before_upgrading_Kernel = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
		Add-Content -Value $modinfo_hv_vmbus_before_upgrading_Kernel -Path "$($VMObject.logDir)\InfoBeforeKernelUpgrade.txt"
        $dmesgBeforeUpgrade = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "dmesg"
        Set-Content -Value $dmesgBeforeUpgrade -Path "$($VMObject.LogDir)\dmesgBeforeKernelUpgrade.txt"
        Add-Content -Value "**************uname -r before upgrading Kernel******************" -Path "$($VMObject.LogDir)\InfoBeforeKernelUpgrade.txt"
		$unameBeforeUpgrade = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "uname -r"
		Add-Content -Value $unameBeforeUpgrade -Path "$($VMObject.logDir)\InfoBeforeKernelUpgrade.txt"
        $dmesgBeforeUpgrade = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "dmesg"
		$UpdateConsole = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install -y kernel" -runAsSudo -runMaxAllowedTime 1500
        Set-Content -Value $UpdateConsole -Path "$($VMObject.LogDir)\UpdateConsoleOutput.txt"
        $dmesgafterUpgrade = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "dmesg"
		Set-Content -Value $dmesgAfterUpgrade -Path "$($VMObject.LogDir)\dmesgAfterKernelUpgrade.txt"
        Add-Content -Value "**************uname -r after upgrading Kernel before reboot ******************" -Path "$($VMObject.LogDir)\InfoAfterKernelUpgrade.txt"
		$unameAfterUpgrade = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "uname -r"
		Add-Content -Value $unameAfterUpgrade -Path "$($VMObject.logDir)\InfoAfterKernelUpgrade.txt"
		
        if($isReboot -imatch "NO")
		{
			if(($UpdateConsole -imatch "already installed") -or ($UpdateConsole -imatch "Nothing to do"))
			{
				LogMsg "VM has latest kernel already installed, So LIS negative scenario test is skipped.."
				LogMsg "Kernel version : $unameBeforeUpgrade `n $UpdateConsole."
				$ExitCode = "ABORTED"
			}
			elseif($UpdateConsole -imatch "Error")
			{
				LogMsg "Kernel upgrade is Failed, So LIS negative scenario test is skipped.."
				LogMsg "Kernel version : $unameBeforeUpgrade `n $UpdateConsole."
				$ExitCode = "FAIL"
			}
			else
			{
				if($unameBeforeUpgrade -ne $unameAfterUpgrade)
				{
					LogMsg "Kernel upgraded from : $unameBeforeUpgrade to $unameAfterUpgrade."
					LogMsg "Upgraded to latest Kernel version. `n**************  PREVIOUS KERNEL VERSION ************** `n$unameBeforeUpgrade `n******************************************************** `n**************  CURRENT KERNEL VERSION ************** `n$unameAfterUpgrade `n********************************************************"
					$ExitCode = "PASS"
				}
				else
				{
					LogMsg "Re Upgrade the kernel.."
					$ReUpdateConsole = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install -y kernel" -runAsSudo -runMaxAllowedTime 1500
					if(($ReUpdateConsole -imatch "already installed") -or ($ReUpdateConsole -imatch"Nothing to do"))
					{
						LogMsg "Kernel upgrade : SUCESS."
						LogMsg "Kernel version : $unameBeforeUpgrade `n $ReUpdateConsole."
						$ExitCode = "PASS"
					}
					else
					{
						LogMsg "Kernel upgrade is Failed, So LIS negative scenario test is skipped.."
						LogMsg "Kernel version : $unameBeforeUpgrade `n $ReUpdateConsole."
						$ExitCode = "FAIL"
					}
				}
			}
			
		}
		else
		{
			if(($UpdateConsole -imatch "already installed") -or ($UpdateConsole -imatch "Nothing to do"))
			{
				LogMsg "VM has latest kernel already installed, So LIS scenario test is skipped.."
				LogMsg "Kernel version : $unameBeforeUpgrade `n $UpdateConsole."
				$ExitCode = "ABORTED"
			}
			elseif($UpdateConsole -imatch "Error")
			{
				if($UpdateConsole -imatch "already installed" )
				{
					LogMsg "Kernel upgrade : SUCESS."
					LogMsg "Kernel version : $unameBeforeUpgrade `n $UpdateConsole."
					$ExitCode = "PASS"
				}
				LogMsg "Kernel upgrade is Failed, So LIS scenario test is skipped.."
				LogMsg "Kernel version : $unameBeforeUpgrade `n $UpdateConsole."
				$ExitCode = "FAIL"
			}
			else
			{
				LogMsg "Kernel upgrade is success, So LIS scenario test forwared with reboot VM.."
				$restartStatus = RestartAllDeployments -allVMData $allVMData
				if ( $restartStatus -eq "True")
				{
					#Verify Kernel and LIS Version
					Add-Content -Value "**************modinfo hv_vmbus after upgrading Kernel******************" -Path "$($VMObject.LogDir)\InfoAfterKernelUpgrade.txt"
					$modinfo_hv_vmbus_after_upgrading_Kernel = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "modinfo hv_vmbus" -runAsSudo -ignoreLinuxExitCode
					Add-Content -Value $modinfo_hv_vmbus_after_upgrading_Kernel -Path "$($VMObject.logDir)\InfoAfterKernelUpgrade.txt"
					Add-Content -Value "**************uname -r after upgrading Kernel******************" -Path "$($VMObject.LogDir)\InfoAfterKernelUpgrade.txt"
					$unameAfterUpgrade = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "uname -r"
					Add-Content -Value $unameAfterUpgrade -Path "$($VMObject.logDir)\InfoAfterKernelUpgrade.txt"
					if ( ($unameBeforeUpgrade -ne $unameAfterUpgrade) -and ($modinfo_hv_vmbus_before_upgrading_Kernel -ne $modinfo_hv_vmbus_after_upgrading_Kernel))
					{
						LogMsg "Kernel upgraded from : $unameBeforeUpgrade to $unameAfterUpgrade."
						LogMsg "Upgraded to latest Kernel version. `n**************  PREVIOUS KERNEL VERSION ************** `n$unameBeforeUpgrade `n******************************************************** `n**************  CURRENT KERNEL VERSION ************** `n$unameAfterUpgrade `n********************************************************"
						LogMsg "LIS Inbuilt drivers are detected.. After Kernel Upgrade. `n**************  PREVIOUS LIS VERSION ************** `n$modinfo_hv_vmbus_before_upgrading_Kernel `n******************************************************** `n**************  CURRENT LIS VERSION ************** `n$modinfo_hv_vmbus_after_upgrading_Kernel `n********************************************************"
						$ExitCode = "PASS"
					}
					else
					{
						LogErr "New LIS version NOT detected."
						$ExitCode = "FAIL"
					}
				}
				else
				{
					LogErr "VM is not accessible after reboot. Further Tests will be aborted."
					$ExitCode = "ABORTED"
				}
			}	
		}
    }
    elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous Aborted test"
    }
return $ExitCode
}

Function ReinstallLIS($VMObject, $PrevTestStatus, $metaData)
{
    if ( $PrevTestStatus -eq "PASS" )
    {
        $UninstallLIS = UninstallLIS -VMObject $VMObject -PrevTestStatus "PASS" -metaData "Uninstalling LIS."
        $ExitCode = InstallLIS -VMObject $VMObject -PrevTestStatus $UninstallLIS -metaData "$metaData"
    }
    elseif ( $PrevTestStatus -eq "FAIL" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous failed test"
    }
    elseif ( $PrevTestStatus -eq  "ABORTED" )
    {
        $ExitCode = "ABORTED"
        LogMsg "Skipping TEST : $metaData due to previous Aborted test"
    }
return $ExitCode
}

Function PrepareVMForLIS4Test ($VMObject, $DetectedDistro)
{
    if ( $DetectedDistro -imatch "CENTOS" )
    {
        $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install --nogpgcheck -y ./epel-release-7-5.noarch.rpm " -runAsSudo -ignoreLinuxExitCode
        $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install --nogpgcheck -y wget tar" -runAsSudo
    }
    elseif ( $DetectedDistro -imatch "REDHAT" )
    {
        $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install --nogpgcheck -y wget tar" -runAsSudo
    }
	elseif ( $DetectedDistro -imatch "ORACLE" )
    {
        $out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "yum install --nogpgcheck -y wget tar sysstat" -runAsSudo 
    }
    else
    {
        LogMsg "LIS is not Support for detected DISTRO"
    }
}

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{
	
	$testVMData = $allVMData
	$VMObject = CreateTestVMNode -ServiceName $allVMData -VIP $testVMData.PublicIP -SSHPort $testVMData.SSHPort -username  $user -password $password -DNSUrl $hs1ServiceUrl -logDir $LogDir
	$DetectedDistro = DetectLinuxDistro -VIP $testVMData.PublicIP -SSHport $testVMData.SSHPort -testVMUser  $user -testVMPassword $password
	RemoteCopy -uploadTo $testVMData.PublicIP -port $testVMData.SSHPort -files $currentTestData.files -username  $user -password $password -upload
	$out = RunLinuxCmd -username $VMObject.username -password $VMObject.password -ip $VMObject.VIP -port $VMObject.SSHPort -command "chmod +x *.sh" -runAsSudo
    $out = PrepareVMForLIS4Test -VMObject $VMObject -DetectedDistro $DetectedDistro
	$testResult = "PASS"
	
	foreach($TestID in $SubtestValues)
	{
		try
		{
			#Make $testResult = $Null
			$PrevTestResult = $testResult
			$testResult = $null
			switch ($TestID.Trim())
			{
			 "manual" #Do manual work if necessory.
				{
					LogMsg "Manual override started.."
					$ManualWork = $null
					While ( !$ManualWork )
					{
						$ManualWork = Read-Host -Prompt "Please tell, what you are trying to do in one line"
					}
					$metaData = $ManualWork
					LogMsg "Please complete your manual work."
					LogMsg "ssh  $user@$hs1ServiceUrl -p $testVMData.SSHPort"
					$isManaulWorkDone = $null
					While ( !( $isManaulWorkDone -eq "YES" ) -and !( $isManaulWorkDone -eq "NO" ) )
					{
						$isManaulWorkDone = Read-Host -Prompt "Did you finished your work? [YES/NO]"
					}
					if ( $isManaulWorkDone -eq "YES" )
					{
						$ProceedForAutomation = $null
						While ( !( $ProceedForAutomation -eq "YES" ) -and !( $ProceedForAutomation -eq "NO" ) )
						{
							$ProceedForAutomation = Read-Host -Prompt "Can Automation proceed? [YES/NO]"
						}
						if ( $ProceedForAutomation -eq "YES")
						{
							$testResult = "PASS"
						}
						else
						{
							$StopAutomationReason = $null
							While ( !$StopAutomationReason )
							{
								$StopAutomationReason = Read-Host -Prompt "Please tell, why automation should stop in one line."
							}
							$testResult = "FAIL"
						}
					}
					else
					{
						$manualWorkNotDoneReason = $null
						While ( !$manualWorkNotDoneReason )
						{
							$manualWorkNotDoneReason = Read-Host -Prompt "Please tell, why manual work is not completed in one line."
						}
						$testResult = "ABORTED"
					}
				}

			"TestID1" #Install Previous LIS version
				{
					$LISVersion = $PreviousLISVersion
					$LISExtractCommand = $PreviousLISExtractCommand
					$metaData = "Pass1 - Install LIS Previous version $LISVersion and Reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					if ( $DetectedDistro -imatch "CENTOS" -or $DetectedDistro -imatch "REDHAT" -or $DetectedDistro -imatch "ORACLE" )
					{
						$testResult = InstallLIS -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData
					}
					else
					{
						LogMsg "Skipping LIS installation for $DetectedDistro"
						$testResult = "PASS"
					}
				}
				
			"TestID2" #Install Current LIS version
				{
					$LISVersion = $CurrentLISVersion
					$LISExtractCommand = $CurrentLISExtractCommand
					$metaData = "Pass1 - Install LIS Current version $LISVersion and Reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					if ( $DetectedDistro -imatch "CENTOS" -or $DetectedDistro -imatch "REDHAT" -or $DetectedDistro -imatch "ORACLE" )
					{
						$testResult = InstallLIS -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData
					}
					else
					{
						LogMsg "Skipping LIS installation for $DetectedDistro"
						$testResult = "PASS"
					}
				}
			
			"TestID3" #Upgrade to Current LIS version
				{
					$LISVersion = $CurrentLISVersion
					$LISExtractCommand = $CurrentLISExtractCommand
					$metaData = "Pass2 - Upgrade to LIS Current version $LISVersion and Reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					if ( $DetectedDistro -imatch "CENTOS" -or $DetectedDistro -imatch "REDHAT" -or $DetectedDistro -imatch "ORACLE" )
					{
						$testResult = UpgradeLIS -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData
					}
					else
					{
						LogMsg "Skipping LIS up-gradation for $DetectedDistro"
						$testResult = "PASS"
					}
				}
			"TestID4" #UnInstall to Current LIS version
				{
					$LISVersion = $CurrentLISVersion
					$LISExtractCommand = $CurrentLISExtractCommand
					$metaData = "Pass3 - Uninstall LIS Current version $LISVersion and Reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					if ( $DetectedDistro -imatch "CENTOS" -or $DetectedDistro -imatch "REDHAT" -or $DetectedDistro -imatch "ORACLE" )
					{
						$testResult = UninstallLIS -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData
					}
					else
					{
						LogMsg "Skipping LIS uninstallation for $DetectedDistro"
						$testResult = "PASS"
					}
				}
				
			 "TestID5" #ReInstall Previous LIS version
				{
					$LISVersion = $PreviousLISVersion
					$LISExtractCommand = $PreviousLISExtractCommand
					$metaData = "Pass4 - ReInstall LIS Previous version $LISVersion and Reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					if ( $DetectedDistro -imatch "CENTOS" -or $DetectedDistro -imatch "REDHAT" -or $DetectedDistro -imatch "ORACLE" )
					{
						$testResult = ReinstallLIS -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData
					}
					else
					{
						LogMsg "Skipping LIS installation for $DetectedDistro"
						$testResult = "PASS"
					}
				}
			"TestID6" # Upgrade kernel with reboot and Verify VM boot with Inbuilt LIS drivers
				{
					$metaData = "Pass2 - Upgrade kernel with reboot and Verify VM boot with Inbuilt LIS drivers"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					$testResult = UpgradeKernel -VMObject $VMObject -PrevTestStatus $PrevTestResult -metaData $metaData -isReboot "YES"
				}
			"TestID7" # Upgrade kernel without reboot
				{
					$metaData = "Pass1 - Upgrade kernel without reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					$testResult = UpgradeKernel -VMObject $VMObject -PrevTestStatus $PrevTestResult -metaData $metaData -isReboot "NO"
				}
		    "TestID8" #Install Current LIS version after upgrade kernel without reboot
				{
					$LISVersion = $CurrentLISVersion
					$LISExtractCommand = $CurrentLISExtractCommand
					$metaData = "Pass2 - Install LIS Current version $LISVersion after upgrade kernel without reboot"
					mkdir "$LogDir\$metaData" -Force | Out-Null
					$VMObject.LogDir = "$LogDir\$metaData"
					if ( $DetectedDistro -imatch "CENTOS" -or $DetectedDistro -imatch "REDHAT" -or $DetectedDistro -imatch "ORACLE" )
					{
						$testResult = InstallLIS -VMObject $VMObject -PrevTestStatus $PrevTestResult  -metaData $metaData -ISAbortIgnore "YES"
					}
					else
					{
						LogMsg "Skipping LIS installation for $DetectedDistro"
						$testResult = "PASS"
					}
				}
			}	
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
			$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "$metaData" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
		} 
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
return $result,$resultSummary