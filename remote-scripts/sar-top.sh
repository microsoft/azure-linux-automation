#!/bin/bash
#
# This script collects all the required logs during the network performance test.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#

duration=$1
filename=$2
username=$3
code_path="/home/$username/code/"

capture_cpu(){
	for i in $(seq 1 $duration)
	do
		date_j=`date +"%T"`
		top_j=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'`
		echo $date_j,$top_j>> $filename-top.csv
		sleep 1
	done
}

capture_connections(){
	for i in $(seq 1 $duration)
	do
		date_i=`date +"%T"`
		netstat_i=`netstat -natp | grep iperf | grep ESTA | wc -l`
		echo $date_i,$netstat_i >> $filename-connections.csv
		sleep 1
	done
}
vm_bus_ver=`modinfo hv_vmbus| grep ^version| awk '{print $2}'`

logs_dir=$code_path/logs-`hostname`-`uname -r`-$vm_bus_ver/$filename
filename=$logs_dir/$filename
mkdir -p  $logs_dir

echo $filename-top.csv $duration $filename $filename-sar.log 
[ -f $filename-top.csv  ] && rm -rf $filename-top.csv 
[ -f $filename-sar.log  ] && rm -rf $filename-sar.log 
[ -f $filename-vmstat.log  ] && rm -rf $filename-vmstat.log 
[ -f $filename-connections.csv  ] && rm -rf $filename-connections.csv

echo "uname: -------------------------------------------------" > $filename-sar.log
uname -a 2>&1 >> $filename-sar.log
echo "LIS version: --------------------------------------------" >> $filename-sar.log
modinfo hv_vmbus 2>&1 >> $filename-sar.log
echo "----------------------------------------------------------" >> $filename-sar.log
echo "Number of CPU cores" `nproc` >> $filename-sar.log
echo "Memory" `free -h| grep Mem| awk '{print $2}'` >> $filename-sar.log
echo "Host Build Version" `dmesg | grep "Host Build" | sed "s/.*Host Build://"| awk '{print  $1}'| sed "s/;//"`  >> $filename-sar.log

sar -n DEV 1 $duration 2>&1 >> $filename-sar.log&
sar_pid=$!
vmstat 1 $duration > $filename-vmstat.log&
vmstat_pid=$!
capture_cpu &
capture_cpu_pid=$!
capture_connections &
capture_connections_pid=$!

sleep $duration
kill -9 $sar_pid $capture_cpu_pid $capture_connections_pid $vmstat_pid
dmesg > $filename-dmesg.log 
exit 0
