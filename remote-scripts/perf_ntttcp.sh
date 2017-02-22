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
# perf_ntttcp.sh
# Author : SHITAL SAVEKAR <v-shisav@microsoft.com>
#
# Description:
#    Download and run ntttcp network performance tests.
#    This script needs to be run on client VM.
#
# Supported Distros:
#    Ubuntu 16.04
#######################################################################

CONSTANTS_FILE="./constants.sh"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test
touch ./ntttcpTest.log

ConfigureNtttcpUbuntu()
{
	LogMsg "Configuring ${1} for ntttcp test..."
	ssh ${1} "apt-get update"
	ssh ${1} "apt-get -y install libaio1 sysstat git bc make gcc"
	ssh ${1} "git clone https://github.com/Microsoft/ntttcp-for-linux.git"
	ssh ${1} "cd ntttcp-for-linux/src/ && make && make install"
	ssh ${1} "cp ntttcp-for-linux/src/ntttcp ."
	ssh ${1} "rm -rf lagscope"
	ssh ${1} "git clone https://github.com/Microsoft/lagscope"
	ssh ${1} "cd lagscope/src && make && make install"
}

LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> ./ntttcpTest.log
}

UpdateTestState()
{
    echo "${1}" > ./state.txt
}

ConfigUbuntu1604()
{
    LogMsg "Running ConfigUbuntu..."
	apt-get update
	apt-get -y install libaio1 sysstat git
}

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ ! ${server} ]; then
	errMsg="Please add/provide value for server in constants.sh. server=<server ip>"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi
if [ ! ${client} ]; then
	errMsg="Please add/provide value for client in constants.sh. client=<client ip>"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

if [ ! ${testDuration} ]; then
	errMsg="Please add/provide value for testDuration in constants.sh. testDuration=60"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

#Make & build ntttcp on client and server Machine

LogMsg "Configuring client ${client}..."
ConfigureNtttcpUbuntu ${client}

LogMsg "Configuring server ${server}..."
ConfigureNtttcpUbuntu ${server}

#Now, start the ntttcp client on client VM.

ssh root@${client} "wget https://raw.githubusercontent.com/iamshital/linux_performance_test/ntttcp10k/run_ntttcp-for-linux/run-ntttcp-and-tcping.sh"
ssh root@${client} "wget https://raw.githubusercontent.com/iamshital/linux_performance_test/ntttcp10k/run_ntttcp-for-linux/report-ntttcp-and-tcping.sh"
ssh root@${client} "chmod +x run-ntttcp-and-tcping.sh && chmod +x report-ntttcp-and-tcping.sh"
LogMsg "Now running NTTTCP test"
ssh root@${client} "rm -rf ntttcp-test-logs"
ssh root@${client} "./run-ntttcp-and-tcping.sh ntttcp-test-logs ${server} root ${testDuration}"
ssh root@${client} "./report-ntttcp-and-tcping.sh ntttcp-test-logs"
ssh root@${client} "cp ntttcp-test-logs/* ."

UpdateTestState ICA_TESTCOMPLETED
