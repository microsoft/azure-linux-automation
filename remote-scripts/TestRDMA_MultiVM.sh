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
#
#
# Description:
#######################################################################

#HOW TO PARSE THE ARGUMENTS.. SOURCE - http://stackoverflow.com/questions/4882349/parsing-shell-script-arguments

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

master=$master
slaves=$slaves
rm -rf /root/TestRDMALogs.txt
#
# Constants/Globals
#
CONSTANTS_FILE="/root/constants.sh"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test
CurrentMachine=""
imb_mpi1_finalStatus=0
imb_rma_finalStatus=0
imb_nbc_finalStatus=0
#######################################################################
#
# LogMsg()
#
#######################################################################
LogMsg()
{
    timeStamp=`date "+%b %d %Y %T"`
    echo "$timeStamp : ${1}"    # Add the time stamp to the log message
    echo "$timeStamp : ${1}" >> /root/TestRDMALogs.txt
}

UpdateTestState()
{
    echo "${1}" > /root/state.txt
}

PrepareForRDMA()
{
        # TODO
        echo Doing Nothing
}
#Get all the Kernel-Logs from all VMs.
CollectKernelLogs()
{
    slavesArr=`echo ${slaves} | tr ',' ' '`
    for vm in $master $slavesArr
    do
                    LogMsg "Getting kernel logs from $vm"
                    ssh root@${vm} "dmesg > kernel-logs-${vm}.txt"
                    scp root@${vm}:kernel-logs-${vm}.txt .
                    if [ $? -eq 0 ];
                    then
                                    LogMsg "Kernel Logs collected successfully from ${vm}."
                    else
                                    LogMsg "Error: Failed to collect kernel logs from ${vm}."
                    fi

    done
}

CompressFiles()
{
    compressedFileName=$1
    pattern=$2
    LogMsg "Compressing ${pattern} files into ${compressedFileName}"
    tar -cvzf ${compressedFileName} ${pattern}*
    if [ $? -eq 0 ];
    then
            LogMsg "${pattern}* files compresssed successfully."
            LogMsg "Deleting local copies of ${pattern}* files"
            rm -rvf ${pattern}*
    else
            LogMsg "Error: Failed to compress files."
            LogMsg "Don't worry. Your files are still here."
    fi
}

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

slavesArr=`echo ${slaves} | tr ',' ' '`
mpirunPath=`find / -name mpirun | grep intel64`
LogMsg "MPIRUN Path: $mpirunPath"
imb_mpi1Path=`find / -name IMB-MPI1 | grep intel64`
LogMsg "IMB-MPI1 Path: $imb_mpi1Path"
imb_rmaPath=`find / -name IMB-RMA | grep intel64`
LogMsg "IMB-RMA Path: $imb_rmaPath"
imb_nbcPath=`find / -name IMB-NBC | grep intel64`
LogMsg "IMB-NBC Path: $imb_nbcPath"

#Verify if eth1 got IP address on All VMs in current cluster.
finaleth1Status=0
totalVMs=0
slavesArr=`echo ${slaves} | tr ',' ' '`
for vm in $master $slavesArr
do
                LogMsg "Checking eth1 status in $vm"
                temp=`ssh root@${vm} "ifconfig eth1 | grep 'inet '"`
                eth1Status=$?
                ssh root@${vm} "ifconfig eth1 > eth1-status-${vm}.txt"
                scp root@${vm}:eth1-status-${vm}.txt .
                if [ $eth1Status -eq 0 ];
                then
                                LogMsg "eth1 IP detected for ${vm}."
                else
                                LogMsg "Error: eth1 failed to get IP address for ${vm}."
                fi
                finaleth1Status=$(( $finaleth1Status + $eth1Status ))
                totalVMs=$(( $totalVMs + 1 ))
done
if [ $finaleth1Status -ne 0 ]; then
                LogMsg "ERROR: Some VMs did get IP address for eth1. Aborting Tests"
                UpdateTestState $ICA_TESTFAILED
                CollectKernelLogs
                LogMsg "INFINIBAND_VERIFICATION_FAILED_ETH1"               
                exit 0
else
                LogMsg "INFINIBAND_VERIFICATION_SUCCESS_ETH1"                
fi



##Verify MPI Tests

#Verify PingPong Tests (IntraNode).
finalMpiIntranodeStatus=0
slavesArr=`echo ${slaves} | tr ',' ' '`
for vm in $master $slavesArr
do
                LogMsg "$mpirunPath -hosts $vm -ppn $mpi1_ppn -n $mpi1_ppn $mpi_settings $imb_mpi1Path pingpong"
                LogMsg "Checking IMB-MPI1 Intranode status in $vm"
                ssh root@${vm} "$mpirunPath -hosts $vm -ppn $mpi1_ppn -n $mpi1_ppn $mpi_settings $imb_mpi1Path pingpong > IMB-MPI1-IntraNode-pingpong-output-$vm.txt"
                mpiIntranodeStatus=$?
                scp root@${vm}:IMB-MPI1-IntraNode-pingpong-output-$vm.txt .
                if [ $mpiIntranodeStatus -eq 0 ];
                then
                                LogMsg "IMB-MPI1 Intranode status in $vm - Succeeded."
                else
                                LogMsg "IMB-MPI1 Intranode status in $vm - Failed"
                fi
                finalMpiIntranodeStatus=$(( $finalMpiIntranodeStatus + $mpiIntranodeStatus ))
done

if [ $finalMpiIntranodeStatus -ne 0 ]; then
                LogMsg "ERROR: IMB-MPI1 Intranode test failed in somes VMs. Aborting further tests."
                UpdateTestState $ICA_TESTFAILED
                CollectKernelLogs
                LogMsg "INFINIBAND_VERIFICATION_FAILED_MPI1_INTRANODE"
                exit 0
else
                LogMsg "INFINIBAND_VERIFICATION_SUCCESS_MPI1_INTRANODE"                
fi

#Verify PingPong Tests (InterNode).
finalMpiInternodeStatus=0
slavesArr=`echo ${slaves} | tr ',' ' '`
for vm in $slavesArr
do
        LogMsg "$mpirunPath -hosts $master,$vm -ppn $mpi1_ppn -n $(( $mpi1_ppn * 2 )) $mpi_settings $imb_mpi1Path pingpong"
        LogMsg "Checking IMB-MPI1 InterNode status in $vm"
        $mpirunPath -hosts $master,$vm -ppn $mpi1_ppn -n $(( $mpi1_ppn * 2 )) $mpi_settings $imb_mpi1Path pingpong > IMB-MPI1-InterNode-pingpong-output-${master}-${vm}.txt
        mpiInternodeStatus=$?
        if [ $mpiInternodeStatus -eq 0 ];
        then
                        LogMsg "IMB-MPI1 Internode status in $vm - Succeeded."
        else
                        LogMsg "IMB-MPI1 Internode status in $vm - Failed"
        fi
        finalMpiInternodeStatus=$(( $finalMpiInternodeStatus + $mpiInternodeStatus ))
done

if [ $finalMpiInternodeStatus -ne 0 ]; then
                LogMsg "ERROR: IMB-MPI1 Internode test failed in somes VMs. Aborting further tests."
                UpdateTestState $ICA_TESTFAILED
                CollectKernelLogs
                LogMsg "INFINIBAND_VERIFICATION_FAILED_MPI1_INTERNODE"
                exit 0
else
                LogMsg "INFINIBAND_VERIFICATION_SUCCESS_MPI1_INTERNODE"                
fi

#Verify IMB-MPI1 (pingpong & allreduce etc) tests.
Attempts=`seq 1 1 $imb_mpi1_tests_iterations`
imb_mpi1_finalStatus=0
for i in $Attempts;
do
                if [[ $imb_mpi1_tests == "all" ]];
                then
                    LogMsg "$mpirunPath -hosts $master,$slaves -ppn $mpi1_ppn -n $(( $mpi1_ppn * $totalVMs )) $mpi_settings $imb_mpi1Path"
                    LogMsg "IMB-MPI1 test iteration $i - Running."
                    $mpirunPath -hosts $master,$slaves -ppn $mpi1_ppn -n $(( $mpi1_ppn * $totalVMs )) $mpi_settings $imb_mpi1Path > IMB-MPI1-AllNodes-output-Attempt-${i}.txt
                    mpiStatus=$?
                else
                    LogMsg "$mpirunPath -hosts $master,$slaves -ppn $mpi1_ppn -n $(( $mpi1_ppn * $totalVMs )) $mpi_settings $imb_mpi1Path $imb_mpi1_tests"
                    LogMsg "IMB-MPI1 test iteration $i - Running."
                    $mpirunPath -hosts $master,$slaves -ppn $mpi1_ppn -n $(( $mpi1_ppn * $totalVMs )) $mpi_settings $imb_mpi1Path $imb_mpi1_tests > IMB-MPI1-AllNodes-output-Attempt-${i}.txt
                    mpiStatus=$?
                fi
                if [ $mpiStatus -eq 0 ];
                then
                                LogMsg "IMB-MPI1 test iteration $i - Succeeded."
                                sleep 1
                else
                                LogMsg "IMB-MPI1 test iteration $i - Failed."
                                imb_mpi1_finalStatus=$(( $imb_mpi1_finalStatus + $mpiStatus ))
                                sleep 1
                fi
done

if [ $imb_mpi1_tests_iterations -gt 5 ];
then
    CompressFiles "IMB-MPI1-AllNodes-output.tar.gz" "IMB-MPI1-AllNodes-output-Attempt"
fi

if [ $imb_mpi1_finalStatus -ne 0 ]; then
                LogMsg "ERROR: IMB-MPI1 tests returned non-zero exit code."
                UpdateTestState $ICA_TESTFAILED
                CollectKernelLogs
                LogMsg "INFINIBAND_VERIFICATION_FAILED_MPI1_ALLNODES"
                exit 0
else
                LogMsg "INFINIBAND_VERIFICATION_SUCCESS_MPI1_ALLNODES"                
                
fi

#Verify IMB-RMA tests.
Attempts=`seq 1 1 $imb_rma_tests_iterations`
imb_rma_finalStatus=0
for i in $Attempts;
do
                if [[ $imb_rma_tests == "all" ]];
                then
                    LogMsg "$mpirunPath -hosts $master,$slaves -ppn $rma_ppn -n $(( $rma_ppn * $totalVMs )) $mpi_settings $imb_rmaPath"
                    LogMsg "IMB-RMA test iteration $i - Running."
                    $mpirunPath -hosts $master,$slaves -ppn $rma_ppn -n $(( $rma_ppn * $totalVMs )) $mpi_settings $imb_rmaPath > IMB-RMA-AllNodes-output-Attempt-${i}.txt
                    rmaStatus=$?
                else
                    LogMsg "$mpirunPath -hosts $master,$slaves -ppn $rma_ppn -n $(( $rma_ppn * $totalVMs )) $mpi_settings $imb_rmaPath $imb_rma_tests"
                    LogMsg "IMB-RMA test iteration $i - Running."
                    $mpirunPath -hosts $master,$slaves -ppn $rma_ppn -n $(( $rma_ppn * $totalVMs )) $mpi_settings $imb_rmaPath $imb_rma_tests > IMB-RMA-AllNodes-output-Attempt-${i}.txt
                    rmaStatus=$?
                fi
                if [ $rmaStatus -eq 0 ];
                then
                                LogMsg "IMB-RMA test iteration $i - Succeeded."
                                sleep 1
                else
                                LogMsg "IMB-RMA test iteration $i - Failed."
                                imb_rma_finalStatus=$(( $imb_rma_finalStatus + $rmaStatus ))
                                sleep 1
                fi
done

if [ $imb_rma_tests_iterations -gt 5 ];
then
    CompressFiles "IMB-RMA-AllNodes-output.tar.gz" "IMB-RMA-AllNodes-output-Attempt"
fi

if [ $imb_rma_finalStatus -ne 0 ]; then
                LogMsg "ERROR: IMB-RMA tests returned non-zero exit code. Aborting further tests."
                UpdateTestState $ICA_TESTFAILED
                CollectKernelLogs
                LogMsg "INFINIBAND_VERIFICATION_FAILED_RMA_ALLNODES"
                exit 0
else
                LogMsg "INFINIBAND_VERIFICATION_SUCCESS_RMA_ALLNODES"                
fi

#Verify IMB-NBC tests.
Attempts=`seq 1 1 $imb_nbc_tests_iterations`
imb_nbc_finalStatus=0
for i in $Attempts;
do
                if [[ $imb_nbc_tests == "all" ]];
                then
                    LogMsg "$mpirunPath -hosts $master,$slaves -ppn $nbc_ppn -n $(( $nbc_ppn * $totalVMs )) $mpi_settings $imb_nbcPath"
                    LogMsg "IMB-NBC test iteration $i - Running."
                    $mpirunPath -hosts $master,$slaves -ppn $nbc_ppn -n $(( $nbc_ppn * $totalVMs )) $mpi_settings $imb_nbcPath > IMB-NBC-AllNodes-output-Attempt-${i}.txt
                    nbcStatus=$?
                else
                    LogMsg "$mpirunPath -hosts $master,$slaves -ppn $nbc_ppn -n $(( $nbc_ppn * $totalVMs )) $mpi_settings $imb_nbcPath $imb_nbc_tests"
                    LogMsg "IMB-NBC test iteration $i - Running."
                    $mpirunPath -hosts $master,$slaves -ppn $nbc_ppn -n $(( $nbc_ppn * $totalVMs )) $mpi_settings $imb_nbcPath $imb_nbc_tests > IMB-NBC-AllNodes-output-Attempt-${i}.txt
                    nbcStatus=$?
                fi
                if [ $nbcStatus -eq 0 ];
                then
                                LogMsg "IMB-NBC test iteration $i - Succeeded."
                                sleep 1
                else
                                LogMsg "IMB-NBC test iteration $i - Failed."
                                imb_nbc_finalStatus=$(( $imb_nbc_finalStatus + $nbcStatus ))
                                sleep 1
                fi
done

if [ $imb_rma_tests_iterations -gt 5 ];
then
    CompressFiles "IMB-NBC-AllNodes-output.tar.gz" "IMB-NBC-AllNodes-output-Attempt"
fi

if [ $imb_nbc_finalStatus -ne 0 ]; then
                LogMsg "ERROR: IMB-RMA tests returned non-zero exit code. Aborting further tests."
                UpdateTestState $ICA_TESTFAILED
                CollectKernelLogs
                LogMsg "INFINIBAND_VERIFICATION_FAILED_NBC_ALLNODES"
                exit 0
else
                LogMsg "INFINIBAND_VERIFICATION_SUCCESS_NBC_ALLNODES"                
fi

CollectKernelLogs

finalStatus=$(( $eth1Status +  $finalMpiIntranodeStatus + $finalMpiInternodeStatus + $imb_mpi1_finalStatus + $imb_rma_finalStatus + $imb_nbc_finalStatus ))
if [ $finalStatus -ne 0 ];
then
                LogMsg LogMsg "eth1Status: $eth1Status,  finalMpiIntranodeStatus:$finalMpiIntranodeStatus, finalMpiInternodeStatus:$finalMpiInternodeStatus, imb_mpi1_finalStatus:$imb_mpi1_finalStatu, imb_rma_finalStatus:$imb_rma_finalStatus, imb_nbc_finalStatus:$imb_nbc_finalStatus"
                UpdateTestState $ICA_TESTFAILED
                LogMsg "INFINIBAND_VERIFICATION_FAILED"
else
                UpdateTestState $ICA_TESTCOMPLETED
                LogMsg "INFINIBAND_VERIFIED_SUCCESSFULLY"
fi