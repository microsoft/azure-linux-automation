#!/bin/bash
#
# This script serves as iperf server.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#
for port_number in `seq 8001 8101`
do
iperf3 -s -D -p $port_number
done

username=$1
code_path="/home/$username/code/"
while [ `netstat -natp | grep iperf | grep ESTA | wc -l` -eq 0 ]
do
sleep 1
echo "waiting..."
done

duration=600
for number_of_connections  in 1 2 4 8 16 32 64 128 256 512 1024 2000 3000 4000 5000 6000
do
for port_number in `seq 8001 8501`
do
iperf3 -s -D -p $port_number
done
bash $code_path/sar-top.sh $duration $number_of_connections $username&
sleep $(($duration+10))
done

vm_bus_ver=`modinfo hv_vmbus| grep ^version| awk '{print $2}'`
logs_dir=logs-`hostname`-`uname -r`-$vm_bus_ver/
bash $code_path/generate_csvs.sh $code_path/$logs_dir
