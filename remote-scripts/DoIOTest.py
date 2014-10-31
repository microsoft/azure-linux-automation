#!/usr/bin/python
#V-SHISAV@MICROSOFT.COM

from azuremodules import *
import argparse
import sys
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--diskPaths', help='Please mention disk path in format /dev/sdX. e.g. -d "/dev/sdc" or you can give multiple disks. e.g. -d "/dev/sdc^/dev/sdd"', required=True, type = str)
parser.add_argument('-f', '--fsType', help='Please mention file system:  ext4 or xfs', required=True, type = str, choices=['ext4', 'xfs'])
args = parser.parse_args()
diskPaths = args.diskPaths
fsType = args.fsType

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
		print(diskPath+"_AVAILABLE")
		#Check if disk has partitions..
		isDiskPartitioned = isAlreadyPartitioned(diskPath)
	
		#if disk has partitions, then delete all partitions..
		if isDiskPartitioned[0] == True:
			print(diskPath+"_ALREADY_PARTITIONED")
			isDeleted = deleteAllPartitions(diskPath, isDiskPartitioned[1])
			isDiskPartitioned = isAlreadyPartitioned(diskPath)
			if isDiskPartitioned[0] == False:
				retValue = True
				print(diskPath+"_PARTITION_DELETED")
			else:
				print(diskPath+"_FAILED_TO_DELETE_PARTITION")
				retValue = False
		else:
			print(diskPath+"_NOT_PARTITIONED")
			retValue = True
	else:
		print(diskPath+"_NOT_AVAILABLE")
		retValue = False
	return retValue

def DoIOTest(diskPath, fsType):
	retValue = False
	if CreatePartition(diskPath):
		print(diskPath+"_PARTITION_CREATED_SUCCESSFULLY")
		if formatPartition(diskPath, fsType):
			print(diskPath+"_PARTITION_FORMATTED_SUCCESSFULLY")
			ioPath = "/diskTest" + diskPath
			Run("mkdir " + ioPath + " -p")
			Run("mount " + diskPath + "1 " + ioPath)
			WriteFileOut = Run("dd if=/dev/zero of="+ ioPath +"/testfile bs=1M count=256 && echo WRITE_FILE_DONE")
			if "WRITE_FILE_DONE" in WriteFileOut:
				print(diskPath+"_FILE_CREATED_SUCCESSFULLY")
				retValue = True
			else:
				print(diskPath+"_FAILED_TO_CREATE_FILE")
				retValue = False
		else:
			print(diskPath+"_FAILED_TO_FORMAT_PARTITION")
			retValue = False
	else:
		print(diskPath+"_FAILED_TO_CREATE_PARTITION")
		retValue = False

	return retValue

def Runtest(diskPaths,fsType):
	diskCount = 0
	successCount = 0
	failCount = 0
	mountPoints = ""
	for diskPath in diskPaths.split("^"):
		RunLog.info("Performing operations on " + diskPath)
		diskCount = diskCount + 1
		if InitialChecks(diskPath):
			ioPath = "/diskTest" + diskPath
			ioResult = DoIOTest(diskPath, fsType)
			if ioResult:
				successCount = successCount + 1
	                        if mountPoints == "":
        	                        mountPoints = ioPath
                	        else:
                        	        mountPoints = mountPoints + "^" + ioPath
			else:
				failCount = failCount + 1
		else:
			failCount = failCount + 1
	for mPoint in mountPoints.split("^"):
		RunLog.info("Unmounting " + mPoint)
		Run("umount "+ mPoint)
	if diskCount == successCount:
		print("FINAL_TEST_RESULT_PASS")
	else:
		print("FINAL_TEST_RESULT_FAIL")

Runtest(diskPaths,fsType)
