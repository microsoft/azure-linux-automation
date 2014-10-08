#!/usr/bin/python
from azuremodules import *
import sys
import time
import os
import re
import linecache
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument('-f', '--fsType', help='Please mention file system of RAID drive:  ext4 or xfs', required=True, type = str, choices=['ext4', 'xfs'])
parser.add_argument('-g', '--groupType', help='Please mention disk group type: RAID / LVM ', required=True, type = str, choices=['RAID','LVM'])
parser.add_argument('-m', '--mountpoint', help='Please mention disk mount point Ex: /data ', required=True, type = str)

current_distro	=	"unknown"
distro_version	=	"unknown"
args = parser.parse_args()
fsType = args.fsType
groupType = args.groupType
mount_dir = args.mountpoint

def isDiskAvailable(diskPath):
	RunLog.info("Checking if " + diskPath + " is available or not..")
	fdiskOut = Run("fdisk -l | grep " + diskPath)
	partitionCheckString = diskPath
	retValue = False
	partitionNumbers = ""
	for line in fdiskOut.splitlines():
		if  diskPath in line:
			retValue = True
	return retValue

def isAlreadyPartitioned(diskPath):
	RunLog.info("Checking if " + diskPath + " is partitioned or not..")
	fdiskOut = Run("fdisk -l | grep " + diskPath)
	partitionCheckString = "^"+diskPath+"\d"
	retValue = False
	partitionNumbers = ""
	for line in fdiskOut.splitlines():
		if  re.match(partitionCheckString, line):
			RunLog.info("Found " + line.strip() + " partition..")
			if partitionNumbers == "":
				partitionNumbers = line[8]
			else:
				partitionNumbers = partitionNumbers + "^" + line[8]
			retValue = True
	return retValue,partitionNumbers

def deleteAllPartitions(diskPath, partitionNumbers):
	retValue = False
	if "^" in partitionNumbers:
		RunLog.info("Deleting Multiple partitiones..")
	else:
		RunLog.info("Deleting " + diskPath + "1 partition..")
		deletePartition = Run("(echo d; echo; echo w;) | fdisk " + diskPath)
		if "has been altered" in deletePartition:
			RunLog.info("Deleted.")
			retValue = True
	return retValue

def CreatePartition(diskPath):
	retValue = False
	RunLog.info("Creating " + diskPath + "1 partition..")
	if groupType == "RAID":
		createPartOut = Run("(echo n; echo p; echo 1; echo; echo; echo t; echo fd; echo w;) | fdisk " + diskPath)
	else:
		createPartOut = Run("(echo n; echo p; echo 1; echo; echo; echo w;) | fdisk " + diskPath)
	isSuccessfull = isAlreadyPartitioned(diskPath)
	if isSuccessfull[0] == True:
		retValue = True
		RunLog.info("Partition created successfully")
	else:
		retValue = False
	return retValue	

def formatPartition(diskPath, fsType):
	retValue = False
	RunLog.info("Formatting " + diskPath + "1 with " + fsType + " file system")
	if fsType == "xfs":
		formatOut = Run("mkfs." + fsType + " -f " + diskPath + "1 && echo FS_FORMATTED_SUCCESSFULLY")
	elif fsType == "ext4":
		formatOut = Run("mkfs." + fsType + " " + diskPath + "1 && echo FS_FORMATTED_SUCCESSFULLY")
	if "FS_FORMATTED_SUCCESSFULLY" in formatOut:
		retValue = True
	else:
		retValue = False
	return retValue

def InitialChecks(diskPath):
	retValue = False
	if isDiskAvailable(diskPath):
		RunLog.info(diskPath+"_AVAILABLE")
		#Check if disk has partitions..
		isDiskPartitioned = isAlreadyPartitioned(diskPath)

		#if disk has partitions, then delete all partitions..
		if isDiskPartitioned[0] == True:
			RunLog.info(diskPath+"_ALREADY_PARTITIONED")
			isDeleted = deleteAllPartitions(diskPath, isDiskPartitioned[1])
			isDiskPartitioned = isAlreadyPartitioned(diskPath)
			if isDiskPartitioned[0] == False:
				retValue = True
				RunLog.info(diskPath+"_PARTITION_DELETED")
			else:
				RunLog.info(diskPath+"_FAILED_TO_DELETE_PARTITION")
				retValue = False
		else:
			RunLog.info(diskPath+"_NOT_PARTITIONED")
			retValue = True
	else:
			RunLog.info(diskPath+"_NOT_AVAILABLE")
			retValue = False
	return retValue

def FormatDisk(diskPath, fsType):
	retValue = False
	if CreatePartition(diskPath):
		RunLog.info(diskPath+"_PARTITION_CREATED_SUCCESSFULLY")
		if formatPartition(diskPath, fsType):
			RunLog.info(diskPath+"_PARTITION_FORMATTED_SUCCESSFULLY")
			retValue = True
		else:
			RunLog.info(diskPath+"_FAILED_TO_FORMAT_PARTITION")
			retValue = False
	else:
		RunLog.info(diskPath+"_FAILED_TO_CREATE_PARTITION")
		retValue = False
	return retValue

def FormatAllDisks(diskPaths,fsType):
	diskCount = 0
	successCount = 0
	failCount = 0
	diskString = ""
	for diskPath in diskPaths:
		RunLog.info("Performing operations on " + diskPath)
		diskCount = diskCount + 1
		if InitialChecks(diskPath):
			fdResult = FormatDisk(diskPath, fsType)
			if fdResult:
				successCount = successCount + 1
				if diskString == "":
					diskString = diskPath + "1"
				else:
					diskString = diskString + " " + diskPath + "1"
			else:
				failCount = failCount + 1
		else:
			failCount = failCount + 1
	if diskCount == successCount:
		retValue = True
	else:
		retValue = False
	RunLog.info(str(diskCount) + " " + str(successCount) + " " + diskString)
	return retValue,diskString

def CreateRaid(diskPaths, groupType, fsType):
	isFormatAllDisks = FormatAllDisks(diskPaths,fsType)
	if isFormatAllDisks[0] == True:
		TotalDisks = len(isFormatAllDisks[1].split(" "))
		RunLog.info("Creating " + groupType + " disk combining " + isFormatAllDisks[1])
		RunLog.info("yes | mdadm --create /dev/md1 --level 0 --raid-devices " + str(TotalDisks) + " " + isFormatAllDisks[1] + " && echo SUCCESSFUL")
		createGroupOutput = Run("yes | mdadm --create /dev/md1 --level 0 --raid-devices " + str(TotalDisks) + " " + isFormatAllDisks[1] + " && echo SUCCESSFUL")
		if "SUCCESSFUL" in createGroupOutput :
			RunLog.info("dev_md1_CREATE_SUCCESSFUL")
			RunLog.info(groupType + " /dev/md1 Created successfully")
			if formatPartition("/dev/md", "ext4") :
				RunLog.info("dev_md1_FORMAT_SUCCESSFUL")
			else:
				RunLog.info("dev_md1_FORMAT_FAIL")
				EndOfTheScript("FAIL")
		else:
			RunLog.info("dev_md1_CREATE_FAIL")
			EndOfTheScript("FAIL")
			
	output = Run ("/sbin/blkid ")
	outputlist = re.split("\n", output)
	for line in outputlist:
		matchObj = re.match( r'/dev/md.*UUID="(.*?)".*TYPE="(.*?)".*', line, re.M|re.I)
		if matchObj:
			uuid_from_blkid = matchObj.group(1)
			format_from_blkid = matchObj.group(2)
			Run ("echo ""UUID="+uuid_from_blkid+"\t"+mount_dir+"\t"+format_from_blkid+"\tdefaults 0 2"" >> /etc/fstab")
			RunLog.info( "File updated successfully ...[Done]")
	if not os.path.exists(mount_dir):
		Run("mkdir "+mount_dir)

def CreateLvm(diskPaths, groupType, fsType):
	volume_group_name = "vg1"
	logical_volume_name = "lv1"

	lvm_UUID = "unknown"
	lvm_format = "unknown"
	lvm_device = "unknown"
	
	for i in range(0,len(diskPaths)):
		diskPaths[i] = diskPaths[i]+'1'
	
	Run("yes | pvcreate "+' '.join(diskPaths))
	output = Run("pvdisplay")
	for dev in diskPaths:
		if(output.find('"'+dev+'" is a new physical volume of') == -1):
			RunLog.info ("Not all devices are added to lvm. Aborting")
			EndOfTheScript("FAIL")
	
	output = Run("vgcreate "+volume_group_name+" "+' '.join(diskPaths))
	if(output.find('Volume group "'+volume_group_name+'" successfully created') == -1):
		RunLog.info(volume_group_name+": Volume group is not created. Aborting..")
		EndOfTheScript("FAIL")
		
	output = Run ("echo 'y'| lvcreate -n "+logical_volume_name+" -l 100%FREE "+volume_group_name)
	if(output.find('Logical volume "'+logical_volume_name+'" created') == -1):
		RunLog.info (logical_volume_name+": Logical volume not created. Aborting..")
		EndOfTheScript("FAIL")
	
	output = Run("mkfs."+fsType+" /dev/"+volume_group_name+"/"+logical_volume_name)

	output = Run("blkid")
	outputlist = re.split("\n", output)
	for line in outputlist:
		matchObj = re.match( r'/dev/.*'+volume_group_name+'.*UUID="(.*?)".*TYPE="(.*?)".*', line, re.M|re.I)
		if matchObj:
			lvm_UUID = matchObj.group(1)
			lvm_format = matchObj.group(2)
			lvm_device = line.split(" ")[0][:-1]
			
	if((lvm_UUID == "unknown") or (lvm_format == "unknown") or (lvm_device == "unknown")):
		EndOfTheScript("FAIL")
			
	Run ("echo ""UUID="+lvm_UUID+"\t"+mount_dir+"\t"+lvm_format+"\tdefaults 0 2"" >> /etc/fstab")

	if not os.path.exists(mount_dir):
		Run("mkdir "+mount_dir)
	
def install_iozone():
    RunLog.info( "\nInstall_package: IOZONE")
    if ((current_distro == "ubuntu") or (current_distro == "Debian")):
        return InstallDeb("iozone3_308-1_amd64.deb")
    elif ((current_distro == "rhel") or (current_distro == "Oracle") or (current_distro == 'centos') or (current_distro == "SUSE Linux") or (current_distro == "openSUSE") or (current_distro == "sles")):
        return InstallRpm("iozone-3.424-2.el6.rf.x86_64.rpm")
    else:
        RunLog.error((" Iozone: package installation failed!"))
        RunLog.info((current_distro + ": Unrecognised Distribution OS Linux found!"))
        return False

def EndOfTheScript(result):
	if ((result == 'PASS') or (result == 'FAIL')):
		Run("echo "+result+" >test_result.txt")
	else:
		RunLog.info("Invalid string passed to EndOfTheScript")

	CcollectLogs()
	exit()
	
def CcollectLogs():
	Run("mkdir logs")
	Run("cp -f /tmp/*.log logs/")
	Run("cp -f *.XML logs/")
	Run("cp -f *.log logs/")
	Run("cp -f *.txt logs/")
	Run("dmesg > logs/dmesg")
	Run("tar -czvf logs.tar.gz logs/")
	
#Execution starts from here
[current_distro, distro_version] = DetectDistro()
JustRun("fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort >afterdisk.list")
output = Run("diff beforedisk.list afterdisk.list | grep '/dev/'| awk '{print $2}'")
diskPaths = re.split('\n', output[:-1])
if( not len(diskPaths)):
	RunLog.info ("Disks not attached\n")
	EndOfTheScript("FAIL")

install_iozone()

if (groupType == 'RAID'):
	if(not IinstallPackage("mdadm")):
		if current_distro == "ubuntu":
			InstallDeb("mdadm*.deb")
		else:
			InstallRpm("mdadm*.rpm")
		EndOfTheScript("FAIL")
	CreateRaid(diskPaths, groupType, fsType)
elif(groupType == 'LVM'):
	if(not IinstallPackage("lvm2")):
		EndOfTheScript("FAIL")
	CreateLvm(diskPaths, groupType, fsType)

EndOfTheScript("PASS")	