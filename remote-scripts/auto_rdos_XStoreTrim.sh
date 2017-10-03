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
    echo $1 > $StateFile
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

# 
# Create and delete testfile for Trim test
#
LogMsg "Running TRIM test on /mnt/data to Create 5Gb TEST FILE"
cd /mnt/data;
df -hT | grep /mnt/data
LogMsg "Creating 5GB test file in /mnt/data"
dd if=/dev/zero of=testfile.txt bs=5G count=1
if [ $? -ne 0 ]; then
    LogMsg "Error in creating test file.."
    echo "Creating test file: Failed" >> $SummaryFile
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi
LogMsg "Test file is created on /mnt/data and Waiting for Active pages update."
sleep 300
ls -l
df -hT | grep /mnt/data
LogMsg "Calculate Active pages on TRIM test once test file is created."
#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0