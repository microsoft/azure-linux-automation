#!/bin/bash
#
# This script serves as iperf server.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#

if [[ $# == 1 ]]
then
	username=$1
else
	echo "Usage: bash $0 <vm_loginuser>"
	exit -1
fi

code_path="/home/$username/code/"
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
	done
	bash $code_path/sar-top.sh $duration $number_of_connections $username&
	sleep $(($duration+10))
done

logs_dir=logs-`hostname`-`uname -r`-`get_lis_version`/

collect_VM_properties $code_path/$logs_dir/VM_properties.csv

bash $code_path/generate_csvs.sh $code_path/$logs_dir
