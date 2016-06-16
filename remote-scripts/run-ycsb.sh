#!/bin/bash
# 
# It runs the ycsb bechmark test on given server
# ./run-ycsb.sh <server ip>
#######

test_threads_collection=(1 2 4 8 16 32 64 128 256 512 1024)
server=$1
log_folder="/root/benchmark/mongodb/logs"

echo "Running ycsb benchmark test on server $server"
ssh root@${server} mkdir -p $log_folder

t=0
while [ "x${test_threads_collection[$t]}" != "x" ]
do
	threads=${test_threads_collection[$t]}
	echo "TEST RUNNING WITH: $threads threads"
	# prepare running mongodb-server
	echo "prepare running mongodb-server"
	ssh root@${server} "mkdir -p $log_folder/$threads"
	ssh root@${server} "sar -n DEV 1 900   2>&1 > $log_folder/$threads/$threads.sar.netio.log " & 
	ssh root@${server} "iostat -x -d 1 900 2>&1 > $log_folder/$threads/$threads.iostat.diskio.log " &
	ssh root@${server} "vmstat 1 900 2>&1 > $log_folder/$threads/$threads.vmstat.memory.cpu.log " & 
	
	# prepare running mongodb-benchmark(ycsb)
	echo "prepare running mongodb-benchmark(ycsb)"
	mkdir -p                   $log_folder/$threads
	sar -n DEV 1 900   2>&1 > $log_folder/$threads/$threads.sar.netio.log  & 
	iostat -x -d 1 900 2>&1 > $log_folder/$threads/$threads.iostat.diskio.log &
	vmstat 1 900 2>&1 > $log_folder/$threads/$threads.vmstat.memory.cpu.log & 
	
	#start running the mongodb(ycsb)-benchmark on client
	echo "-> TEST RUNNING with threads $threads .."
	echo "CMD: ./ycsb-0.5.0/bin/ycsb  run  mongodb-async -s -P workloadAzure -p mongodb.url=mongodb://${server}:27017/ycsb?w=0 -threads $threads > $log_folder/$threads/$threads.ycsb.run.log"
	./ycsb-0.5.0/bin/ycsb  run  mongodb-async -s -P workloadAzure -p mongodb.url=mongodb://${server}:27017/ycsb?w=0 -threads $threads > $log_folder/$threads/$threads.ycsb.run.log
	echo "-> TEST END with threads $threads"
	
	#cleanup mongodb-server
	echo "cleanup mongodb-server"
	ssh root@${server} pkill -f sar
	ssh root@${server} pkill -f iostat
	ssh root@${server} pkill -f vmstat

	#cleanup mongodb-benchmark(ycsb)
	echo "cleanup mongodb-benchmark(ycsb)"
	pkill -f sar
	pkill -f iostat
	pkill -f vmstat
	
	echo "sleep 60 seconds"
	sleep 60
	t=$(($t + 1))
	echo "$t"
done
