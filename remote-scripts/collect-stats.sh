#!/bin/bash
duration=$1
filename=$2
capture_cpu(){
for i in $(seq 1 $duration)
do
	date_j=`date +"%x-%T"`
	top_j=`top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'`
	echo $date_j,$top_j>> $filename-top.log
	sleep 1
done
}

capture_connections(){
for i in $(seq 1 $duration)
do
	date_i=`date +"%x-%T"`
	netstat_i=`netstat -nat | grep ESTABLISHED | wc -l`
	echo $date_i,$netstat_i >> $filename-connections.log
	sleep 1
done
}
echo $filename-top.log $duration $filename $filename-sar.log 
[ -f $filename-top.log  ] && rm -rf $filename-top.log 
[ -f $filename-sar.log  ] && rm -rf $filename-sar.log 
[ -f $filename-connections.log  ] && rm -rf $filename-connections.log
sar -n DEV 1 $duration 2>&1 > $filename-sar.log&
sar_pid=$!
capture_cpu &
capture_cpu_pid=$!
capture_connections &
capture_connections_pid=$!
sleep $duration
kill -9 $sar_pid $capture_cpu_pid $capture_connections_pid 
exit 0

