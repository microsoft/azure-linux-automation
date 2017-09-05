#!/bin/bash
############################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
############################################################################

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during running of test

username=$1
CONSTANTS_FILE="constants.sh"
StateFile="/home/$username/state.txt"
SummaryFile="/home/$username/summary.log"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

UpdateTestState()
{
    #echo $1 > ~/state.txt
	echo $1 > $StateFile
}

SetValue()
{
    OLD_VALUE=$(cat $1)
    LogMsg "$1 's old value is $OLD_VALUE"
    if [ "$OLD_VALUE" -ne "$2" ]; then
        LogMsg "Changing $1 to $2"
        echo $2 > $1
    fi
}

#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./$CONSTANTS_FILE ]; then
    LogMsg "CONSTANTS FILE: $(cat $CONSTANTS_FILE)"
    source $CONSTANTS_FILE
else
    echo "Warn : no ${CONSTANTS_FILE} found"
fi

if [ -e $SummaryFile ]; then
    LogMsg "Cleaning up previous copies of summary.log"
    rm -f $SummaryFile
fi

#DATA_DISK=sdb
DATA_DISK=$DATA_DISK
if ! fdisk -l | grep "Disk /dev/$DATA_DISK"; then
    LogMsg "The /dev/$DATA_DISK not found"
    echo "The /dev/$DATA_DISK not found" >> $SummaryFile
    LogMsg "aborting the test."
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

SetValue /sys/module/scsi_mod/parameters/scsi_logging_level 63
SetValue /sys/block/$DATA_DISK/device/timeout 180

echo "Test data disk : /dev/$DATA_DISK" >> $SummaryFile
DATA_PARTITION=/dev/${DATA_DISK}1

# Create data partition
df -hT | grep $DATA_PARTITION && umount $DATA_PARTITION
[ -b $DATA_PARTITION ] && (echo p; echo d; echo p; echo w) | fdisk /dev/$DATA_DISK
(echo n; echo p; echo 1; echo; echo; echo w) | fdisk /dev/$DATA_DISK
if [ $? -ne 0 ]; then
    LogMsg "Error in creating data partition.."
    echo "Creating data partition : Failed" >> $SummaryFile
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi
LogMsg "$DATA_PARTITION data partition is created successfully..."

# Format DATA_PARTITION
LogMsg "File System type is $trimParam"
if [ "$trimParam" == "BTRFS" ]
then
    LogMsg "Formatting $DATA_PARTITION with BTRFS FS"
    mkfs.btrfs -f $DATA_PARTITION || mkfs.btrfs $DATA_PARTITION
elif [ "$trimParam" == "XFS" ]
then
    LogMsg "Formatting $DATA_PARTITION with XFS FS"
    mkfs.xfs -f $DATA_PARTITION || mkfs.xfs $DATA_PARTITION
elif [ "$trimParam" == "EXT4" ]
then
    if grep -q "SUSE Linux Enterprise Server 11" /etc/*-release
    then
        LogMsg "Formatting $DATA_PARTITION with ext3 FS"
        mkfs.ext3 -E lazy_itable_init=0 $DATA_PARTITION
    else
        LogMsg "Formatting $DATA_PARTITION with ext4 FS"
        mkfs.ext4 -E lazy_itable_init=0 $DATA_PARTITION
    fi
else
    echo "Please pass valid File System type"
    exit 80
fi
if [ $? -ne 0 ]; then
    LogMsg "Error in creating file system.."
    echo "Creating file system : Failed" >> $SummaryFile
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi
LogMsg "$DATA_PARTITION is formatted successfully..."

find /sys/devices -name 'provisioning_mode' -exec sh -c 'echo -n unmap > $1' -- {} \;

# mount DATA_PARTITION
[ ! -d /mnt/data ] && mkdir /mnt/data
LogMsg "Mounting $DATA_PARTITION with discard option"
mount -o discard $DATA_PARTITION /mnt/data || mount $DATA_PARTITION /mnt/data
if [ $? -eq 0 ]; then
    LogMsg "Drive mounted successfully..."    
else
    LogMsg "Error in mounting drive..."
    echo "Drive mount : Failed" >> $SummaryFile
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

if ! grep -q "SUSE Linux Enterprise Server 11" /etc/*-release
then
    LogMsg "Re-mounting / with discard option"
    mount -o remount,discard /
fi

#Block size details
LogMsg "Block size used for TRIM test :"
blockdev --getbsz /dev/sdb1

#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0