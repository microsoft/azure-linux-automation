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
	ssh ${1} "apt-get -y install libaio1 sysstat git"
	ssh ${1} "git clone https://github.com/Microsoft/ntttcp-for-linux.git"
	ssh ${1} "cd ntttcp-for-linux/src/ && make && make install"
	ssh ${1} "cp ntttcp-for-linux/src/ntttcp ."
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
if [ ! ${connections} ]; then
	errMsg="Please add/provide value for connections in constants.sh. connections=(1 2 4 8 16)"
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

#start ntttcp on server-vm in receiver mode.
LogMsg "Starting nttcp server in ${server}"
ssh ${server} "pkill ntttcp"
ssh ${server} "./ntttcp -r > ntttcp-server-logs.txt &"

#Now, start the ntttcp client on client VM.
i=1
for currenttest in "${connections[@]}"
do
	ssh ${server} "sar -n DEV 1 900"   2>&1 > ntttcp-server-logs-test#${i}-connections-${currenttest}.sar.netio.log  &
	ssh ${server} "iostat -x -d 1 900" 2>&1 > ntttcp-server-logs-test#${i}-connections-${currenttest}.iostat.diskio.log  &
	ssh ${server} "vmstat 1 900"       2>&1 > ntttcp-server-logs-test#${i}-connections-${currenttest}.vmstat.memory.cpu.log  &

	ssh ${client} "sar -n DEV 1 900"   2>&1 > ntttcp-client-logs-test#${i}-connections-${currenttest}.sar.netio.log  &
	ssh ${client} "iostat -x -d 1 900" 2>&1 > ntttcp-client-logs-test#${i}-connections-${currenttest}.iostat.diskio.log &
	ssh ${client} "vmstat 1 900"       2>&1 > ntttcp-client-logs-test#${i}-connections-${currenttest}.vmstat.memory.cpu.log &

	LogMsg "Starting ntttcp with ${currenttest} connections..."
	ssh ${client} "./ntttcp -s${server} -n${currenttest} > ntttcp-client-logs-test#${i}-connections-${currenttest}.ConsoleResult.txt"
	
	ssh ${client} pkill -f sar 2>&1 > /dev/null
	ssh ${client} pkill -f iostat 2>&1 > /dev/null
	ssh ${client} pkill -f vmstat 2>&1 > /dev/null	
	
	ssh ${server} pkill -f sar 2>&1 > /dev/null
	ssh ${server} pkill -f iostat 2>&1 > /dev/null
	ssh ${server} pkill -f vmstat 2>&1 > /dev/null	
	
	i=`expr $i + 1`
done

UpdateTestState ICA_TESTCOMPLETED
