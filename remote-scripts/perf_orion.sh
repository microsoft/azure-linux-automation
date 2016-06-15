#!/bin/bash

#######################################################################
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
#######################################################################

#######################################################################
#
# perf_orion.sh
# Author : SHITAL SAVEKAR <v-shisav@microsoft.com>
#
# Description:
#    Download and run orion disk performance tests.
#    This script needs to be run on single VM with one data disk attached.
#    This script requires orion.lun file to be present in pwd. It contains the disk names on which we need to perform the test.
#    orion.lun:
#    /dev/sdc
#
# Supported Distros:
#    Ubuntu 16.04
#######################################################################

CONSTANTS_FILE="./constants.sh"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test
touch ./orionTest.log

LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> ./orionTest.log
}

UpdateTestState()
{
    echo "${1}" > ./state.txt
}

ConfigUbuntu1604()
{
    LogMsg "Running ConfigUbuntu..."
	apt-get update
	apt-get -y install libaio1
}

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

ConfigUbuntu1604

if [ -e orion_x86_64 ]; then
    LogMsg "orion binary already exists."
else
    wget ${orionBinaryURL}
fi
chmod +x ./orion_x86_64

UpdateTestState "TestRunning"
#all read
testType="oltp"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run oltp -testname orion
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="dss"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run dss -testname orion
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="simple"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run simple -testname orion
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="normal#1"
LogMsg "Running $testType test iteration #1.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run normal -testname orion
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

#redo the "normal" test

testType="normal#2"
LogMsg "Running $testType test iteration #2.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run normal -testname orion
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="normal#3"
LogMsg "Running $testType test iteration #3.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run normal -testname orion
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

#all write

testType="oltpWrite100"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run oltp -testname orion -write 100
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="dssWrite100"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run dss -testname orion -write 100
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="advancedWrite100Basic"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 100 -duration 60 -matrix basic
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="advancedWrite100Detailed#1"
LogMsg "Running $testType test iteration #1.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 100 -duration 60 -matrix detailed
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

#redo the "normal" test
testType="advancedWrite100Detailed#2"
LogMsg "Running $testType test iteration #2.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 100 -duration 60 -matrix detailed
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="advancedWrite100Detailed#3"
LogMsg "Running $testType test iteration #3.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 100 -duration 60 -matrix detailed
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

#read50% and write 50%
testType="oltpWrite50"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run oltp -testname orion -write 50 
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="dssWrite50"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run dss -testname orion -write 50
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="advancedWrite50Basic"
LogMsg "Running $testType test.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 50 -duration 60 -matrix basic
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="advancedWrite50Detailed#1"
LogMsg "Running $testType test iteration #1.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 50 -duration 60 -matrix detailed
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

#redo the "normal" test
testType="advancedWrite50Detailed#2"
LogMsg "Running $testType test iteration #2.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 50 -duration 60 -matrix detailed
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

testType="advancedWrite50Detailed#3"
LogMsg "Running $testType test iteration #3.."
dateTime="$(date +"%m-%d-%Y-%H-%M-%S")"
./orion_x86_64 -run advanced -size_small 8 -size_large 1024 -type rand -simulate concat -write 50 -duration 60 -matrix detailed
mv *_iops.csv "orion-${testType}-${dateTime}-iops.csv"
mv *_lat.csv "orion-${testType}-${dateTime}-lat.csv"
mv *_mbps.csv "orion-${testType}-${dateTime}-mbps.csv"
mv *_summary.txt "orion-${testType}-${dateTime}-summary.txt"
mv *_trace.txt "orion-${testType}-${dateTime}-trace.txt"
LogMsg "$testType test finished."

UpdateTestState "TestCompleted"
