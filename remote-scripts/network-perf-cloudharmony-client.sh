#!/bin/bash
#This script will connect iperf client to server for executing network performance tests using different iperf options 
#And also format the test results using CSV.
server_ip=$1
readarray  options < perf-cloudharmony-options.txt
logs_dir=~/logs
[ -d $logs_dir ] && rm -rf $logs_dir
mkdir $logs_dir
count=0
killall iperf3
echo "IPERF test started" > ~/teststatus.txt
while [ "x${options[count]}" != "x" ]
do
	echo ${options[$count]}
	echo "IPERF test ${options[$count]} running" >> ~/teststatus.txt
	file_tag=`echo ${options[$count]}| sed s/-//g| sed "s/ /_/g"`
	echo $file_tag
	iperf3 -c $server_ip ${options[$count]} > $logs_dir/$file_tag.log
	count=$(( $count + 1 )) 
	sleep 30
done
echo "IPERF test completed" >> ~/teststatus.txt

#formatting iperf3logs into csv:
mkdir $logs_dir/csvs
cd $logs_dir/
options=(`ls *.log | grep "_u_"|sed s/\.log//`)
echo "CSV test started" >> ~/teststatus.txt
count=0
while [ "x${options[count]}" != "x" ]
do
	echo "${options[count]}"
	tail -n+5 ${options[count]}.log | awk '!($1="")' | awk '!($1="")' | awk '{$1=$1}1' OFS=","| sed s/\(// | sed s/\)//| sed s/-/,/ | sed s/%//>$logs_dir//csvs/${options[count]}.csv
	count=$(( $count + 1 )) 
done

options=(`ls *.log | grep -v "_u_"|sed s/\.log//`)

count=0
while [ "x${options[count]}" != "x" ]
do
	echo "${options[count]}"
	cat ${options[count]}.log  | grep SUM |awk '!($1="")'  | awk '{$1=$1}1' OFS=","| sed s/\(// | sed s/\)//|sed s/-/,/ | sed s/%//>$logs_dir//csvs/${options[count]}.csv
	count=$(( $count + 1 )) 
done
echo "CSV test completed" >> ~/teststatus.txt
cd ~
tar -cvf logs.tar logs
echo "PERF test completed" >> ~/teststatus.txt

exit 0