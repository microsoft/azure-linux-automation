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
# perf_redis.sh
# Author : SHITAL SAVEKAR <v-shisav@microsoft.com>
#
# Description:
#    Download and run redis benchmark tests.
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
touch ./redisTest.log
ConfigureRedisUbuntu()
{
        LogMsg "Configuring ${1} for redis test..."
        ssh ${1} "apt-get update"
        ssh ${1} "apt-get -y install libaio1 sysstat gcc"
        ssh ${1} "wget http://download.redis.io/releases/redis-${redisVersion}.tar.gz"
        ssh ${1} "tar -xvf  redis-${redisVersion}.tar.gz && cd redis-${redisVersion}/ && make && make install"
        ssh ${1} "cp -ar redis-${redisVersion}/src/* ."
        LogMsg "${1} configured for Redis."
}

LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo `date "+%b %d %Y %T"` : "${1}" >> ./redisTest.log
}

UpdateTestState()
{
    LogMsg "${1}" > ./state.txt
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
        LogMsg "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi
LogMsg "Server=${server}"

if [ ! ${client} ]; then
        errMsg="Please add/provide value for client in constants.sh. client=<client ip>"
        LogMsg "${errMsg}"
        LogMsg "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

LogMsg "Client=${client}"
if [ ! ${test_pipeline_collection} ]; then
        errMsg="Please add/provide value for test_pipeline_collection in constants.sh. test_pipeline_collection=(1 2 4 8 16)"
        LogMsg "${errMsg}"
        LogMsg "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi
LogMsg "test_pipeline_collection=${test_pipeline_collection}"

if [ ! ${redisVersion} ]; then
        errMsg="Please add/provide value for redisVersion in constants.sh. redisVersion=2.8.17"
        LogMsg "${errMsg}"
        LogMsg "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi
LogMsg "redisVersion=${redisVersion}"
if [ ! ${redis_test_suites} ]; then
        errMsg="Please add/provide value for redis_test_suites in constants.sh. redis_test_suites=get,set"
        LogMsg "${errMsg}"
        LogMsg "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

#Make & build Redis on client and server Machine

LogMsg "Configuring client ${client}..."
ConfigureRedisUbuntu ${client}

LogMsg "Configuring server ${server}..."
ConfigureRedisUbuntu ${server}

pkill -f redis-benchmark
ssh root@${server} pkill -f redis-server > /dev/null

t=0
while [ "x${test_pipeline_collection[$t]}" != "x" ]
do
        pipelines=${test_pipeline_collection[$t]}
        LogMsg "NEXT TEST: $pipelines pipelines"

        # prepare running redis-server
        LogMsg "Starting redis-server..."
        ssh root@${server} "sar -n DEV 1 900"   2>&1 > redis-server-pipelines-${pipelines}.sar.netio.log  &
        ssh root@${server} "iostat -x -d 1 900" 2>&1 > redis-server-pipelines-${pipelines}.iostat.diskio.log  &
        ssh root@${server} "vmstat 1 900"       2>&1 > redis-server-pipelines-${pipelines}.vmstat.memory.cpu.log  &

		#start running the redis-server on server		
        ssh root@${server} "./redis-server  > /dev/null  &"
        LogMsg "Server started successfully. Sleeping 10 Secondss.."
        sleep 10

        # prepare running redis-benchmark
        sar -n DEV 1 900   2>&1  > redis-client-pipelines-${pipelines}.sar.netio.log &
        iostat -x -d 1 900 2>&1  > redis-client-pipelines-${pipelines}.iostat.diskio.log &
        vmstat 1 900       2>&1  > redis-client-pipelines-${pipelines}.vmstat.memory.cpu.log &

        #start running the redis-benchmark on client
        LogMsg "Starting redis-benchmark on client..."
        LogMsg "-> Test running with ${pipelines} pipelines."
        ./redis-benchmark -h $server -c 1000 -P $pipelines -t $redis_test_suites -d 4000 -n 10000000 > redis-client-pipelines-${pipelines}.set.get.log
        LogMsg "-> done"

        #cleanup redis-server
        LogMsg "Cleaning Server..."
        ssh root@${server} pkill -f sar 2>&1 > /dev/null
        ssh root@${server} pkill -f iostat 2>&1 > /dev/null
        ssh root@${server} pkill -f vmstat 2>&1 > /dev/null
        ssh root@${server} pkill -f redis-server 2>&1 > /dev/null

        #cleanup redis-benchmark
        LogMsg "Cleaning Client..."
        pkill -f sar 2>&1 > /dev/null
        pkill -f iostat 2>&1 > /dev/null
        pkill -f vmstat 2>&1 > /dev/null
        pkill -f redis-benchmark 2>&1 > /dev/null
        t=$(($t + 1))
		LogMsg "Sleeping 30 Seconds..."
		sleep 30
done
UpdateTestState ICA_TESTCOMPLETED