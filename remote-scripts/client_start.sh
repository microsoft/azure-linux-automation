#!/bin/bash
#
# This script serves as iperf client.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#
server_ip=$1
username=$2
echo "Sleeping 5 mins to get the server ready.."
sleep 300
port_number=8001
duration=600
code_path="/home/$username/code/"
for number_of_connections in 1 2 4 8 16 32 64 128 256 512 1024 2000 3000 4000 5000 6000
do
	bash $code_path/sar-top.sh $duration $number_of_connections $username&

	echo "Starting client with $number_of_connections connections"
	while [ $number_of_connections -gt 64 ]; do
		number_of_connections=$(($number_of_connections-64))
		iperf3 -c $server_ip -p $port_number -P 64 -t $duration > /dev/null &
		port_number=$((port_number+1))
	done
	if [ $number_of_connections -ne 0 ] 
	then
		iperf3 -c $server_ip -p $port_number -P $number_of_connections -t $duration > /dev/null &
	fi

	connections_count=`netstat -natp | grep iperf | grep ESTA | wc -l`
	echo "$connections_count iperf clients are connected to server"
	sleep $(($duration+10))
done
echo ""
exit 0

vm_bus_ver=`modinfo hv_vmbus| grep ^version| awk '{print $2}'`
logs_dir=logs-`hostname`-`uname -r`-$vm_bus_ver/
bash $code_path/generate_csvs.sh $code_path/$logs_dir
tar -cvf $logs_dir.tar $logs_dir/
