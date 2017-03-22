#!/bin/bash
#
# This script serves as iperf server.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#

if [[ $# == 1 ]]
then
	username=$1
elif [[ $# == 3 ]]
then
	username=$1
	testtype=$2
	buffersize=$3
else
	echo "Usage: bash $0 <vm_loginuser>"
	exit -1
fi

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during running of test

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

UpdateTestState()
{
    echo $1 > $code_path/state.txt
}

#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

code_path="/home/$username/code"
. $code_path/azuremodules.sh

if [[ `which iperf3` == "" ]]
then
    echo "iperf3 not installed\n Installing now..."
    install_package "iperf3"
fi

for port_number in `seq 8001 8101`
do
	iperf3 -s -D -p $port_number
done

while [ `netstat -natp | grep iperf | grep ESTA | wc -l` -eq 0 ]
do
	sleep 1
	echo "waiting..."
done

duration=300
for number_of_connections  in 1 2 4 8 16 32 64 128 256 512 1024
do
	for port_number in `seq 8001 8501`
	do
		iperf3 -s -D -p $port_number
		if [ $? -ne 0 ]; then
			LogMsg "iperf3 failed to connect server"
			echo "iperf3 failed to connect server"
			UpdateTestState $ICA_TESTFAILED
			exit 80
		fi
	done
	bash $code_path/sar-top.sh $duration $number_of_connections $username $testtype $buffersize&
	if [ $? -ne 0 ]; then
		LogMsg "sar-top failed to execute"
		echo "sar-top failed to execute"
		UpdateTestState $ICA_TESTFAILED
		exit 80
	fi
	sleep $(($duration+10))
done

logs_dir=logs-`hostname`-$testtype-$buffersize

collect_VM_properties $code_path/$logs_dir/VM_properties.csv

bash $code_path/generate_csvs.sh $code_path/$logs_dir $testtype $buffersize
if [ $? -ne 0 ]; then
	LogMsg "Failed to generate test results .csv file"
	echo "Failed to generate test results .csv file"
	UpdateTestState $ICA_TESTFAILED
	exit 80
fi
mv /etc/rc.d/after.local.bkp /etc/rc.d/after.local
mv /etc/rc.local.bkp /etc/rc.local
mv /etc/rc.d/rc.local.bkp /etc/rc.d/rc.local
echo "$testtype $buffersize test is Completed at Server"

#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED