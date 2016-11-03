#!/bin/bash
#
# This script serves as iperf client.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#

if [[ $# == 4 ]]
then
	server_ip=$1
	username=$2
	testtype=$3
	buffersize=$4
	if [[ $testtype == "UDP" ]]
	then
		testtypeOption=" -u"
		buffersizeOption=" -l $buffersize"
	else
		testtype=""
	fi
else
	echo "Usage: bash $0 <server_ip> <vm_loginuser>"
	exit -1
fi

code_path="/home/$username/code/"
. $code_path/azuremodules.sh

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


if [[ `which iperf3` == "" ]]
then
    echo "iperf3 not installed\n Installing now..."
    install_package "iperf3"
fi

echo "Sleeping 5 mins to get the server ready.."
sleep 300
port_number=8001
duration=300
code_path="/home/$username/code"
for number_of_connections in 1 2 4 8 16 32 64 128 256 512 1024

do
	bash $code_path/sar-top.sh $duration $number_of_connections $username $testtype $buffersize&
	if [ $? -ne 0 ]; then
		LogMsg "sar-top failed to execute"
		echo "sar-top failed to execute"
		UpdateTestState $ICA_TESTFAILED
		exit 80
	fi
	echo "Starting client with $number_of_connections connections"
	while [ $number_of_connections -gt 64 ]; do
		number_of_connections=$(($number_of_connections-64))
		iperf3 -c $server_ip -p $port_number -P 64 -t $duration $testtypeOption $buffersizeOption > /dev/null &
		if [ $? -ne 0 ]; then
			LogMsg "iperf3 failed to connect server"
			echo "iperf3 failed to connect server"
			UpdateTestState $ICA_TESTFAILED
			exit 80
		fi
		port_number=$((port_number+1))
	done
	if [ $number_of_connections -ne 0 ]
	then
		iperf3 -c $server_ip -p $port_number -P $number_of_connections -t $duration $testtypeOption $buffersizeOption > /dev/null &
		if [ $? -ne 0 ]; then
			LogMsg "iperf3 failed to connect server"
			echo "iperf3 failed to connect server"
			UpdateTestState $ICA_TESTFAILED
			exit 80
		fi
	fi

	connections_count=`netstat -natp | grep iperf | grep ESTA | wc -l`
	echo "$connections_count iperf clients are connected to server"
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
echo "$testtype $buffersize test is Completed at Client"
#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED