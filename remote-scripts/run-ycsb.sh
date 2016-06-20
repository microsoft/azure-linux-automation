#!/bin/bash
# 
# It runs the ycsb bechmark test on given server
# ./run-ycsb.sh 
#######
CONSTANTS_FILE="/root/constants.sh"

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    echo "${errMsg}" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

log_folder="/root/benchmark/mongodb/logs"

echo "Running ycsb benchmark test on server $MD_SERVER"
ssh root@${MD_SERVER} mkdir -p $log_folder

t=0
while [ "x${test_threads_collection[$t]}" != "x" ]
do
	threads=${test_threads_collection[$t]}
	echo "TEST RUNNING WITH: $threads threads"
	# prepare running mongodb-server
	echo "prepare running mongodb-server"
	ssh root@${MD_SERVER} "mkdir -p $log_folder/$threads"
	ssh root@${MD_SERVER} "sar -n DEV 1 ${maxexecutiontime}   2>&1 > $log_folder/$threads/$threads.sar.netio.log " & 
	ssh root@${MD_SERVER} "iostat -x -d 1 ${maxexecutiontime} 2>&1 > $log_folder/$threads/$threads.iostat.diskio.log " &
	ssh root@${MD_SERVER} "vmstat 1 ${maxexecutiontime} 2>&1 > $log_folder/$threads/$threads.vmstat.memory.cpu.log " & 
	
	# prepare running mongodb-benchmark(ycsb)
	echo "prepare running mongodb-benchmark(ycsb)"
	mkdir -p $log_folder/$threads
	sar -n DEV 1 ${maxexecutiontime}   2>&1 > $log_folder/$threads/$threads.sar.netio.log  & 
	iostat -x -d 1 ${maxexecutiontime} 2>&1 > $log_folder/$threads/$threads.iostat.diskio.log &
	vmstat 1 ${maxexecutiontime} 2>&1 > $log_folder/$threads/$threads.vmstat.memory.cpu.log & 
	
	#start running the mongodb(ycsb)-benchmark on client
	echo "-> TEST RUNNING with threads $threads .."
	echo "CMD: ./ycsb-0.5.0/bin/ycsb  run  mongodb-async -s -P workloadAzure -p mongodb.url=mongodb://${MD_SERVER}:27017/ycsb?w=0 -threads $threads > $log_folder/$threads/$threads.ycsb.run.log"
	./ycsb-0.5.0/bin/ycsb  run  mongodb-async -s -P workloadAzure -p mongodb.url=mongodb://${MD_SERVER}:27017/ycsb?w=0 -threads $threads > $log_folder/$threads/$threads.ycsb.run.log
	echo "-> TEST END with threads $threads"
	
	#cleanup mongodb-server
	echo "cleanup mongodb-server"
	ssh root@${MD_SERVER} pkill -f sar
	ssh root@${MD_SERVER} pkill -f iostat
	ssh root@${MD_SERVER} pkill -f vmstat

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
