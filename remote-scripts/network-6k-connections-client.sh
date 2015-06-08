#!/bin/bash
#Generating different number of tcp connections (from 1 to 6K) and collect the throughput, Cpu usage and number of re-transmitted packet info.
#And also format the test results using CSV.
#Prerequisites: iperf3, sysstat(for sar), dos2unix
server_ip=$1
duration=600
threads=(1 2 4 8 16 32 64 128 256 512 1024 2000 3000 4000 5000 6000)
i=0
logs_dir=~/logs
[ -d $logs_dir ] && rm -rf $logs_dir
mkdir $logs_dir
[ -f ~/teststatus.txt ] && rm -rf ~/teststatus.txt
killall iperf3
echo "IPERF test started" > ~/teststatus.txt
while [ "x${threads[$i]}" != "x" ]
do
	port=8001
	number_of_connections=${threads[$i]}
	echo "Current no of connections: $number_of_connections"
	echo "IPERF test running for $number_of_connections connections" >> ~/teststatus.txt
	presenttestlog=$logs_dir/${threads[$i]}
	mkdir $presenttestlog
	count=1
	bash ./perf-statistics.sh $duration $presenttestlog &
	while [ $number_of_connections -gt 64 ]; do
		number_of_connections=$(($number_of_connections-64))
		options="-p $port -P 64 -t $duration"
		file_tag=`echo $options| sed s/-//g| sed "s/ /_/g"`
		log_file=`echo ${threads[$i]}-$count-$file_tag-iperf.log| sed "s/-/_/g"`
		echo $log_file
		iperf3 -c $server_ip $options > $presenttestlog/$log_file &
		port=$((port+1))
		count=$((count+1))
	done
	options="-p $port -P $number_of_connections -t $duration"
	file_tag=`echo $options| sed s/-//g| sed "s/ /_/g"`
	log_file=`echo ${threads[$i]}-$count-$file_tag-iperf.log| sed "s/-/_/g"`
	echo $log_file
	iperf3 -c $server_ip $options > $presenttestlog/$log_file
	i=$(($i + 1))
	port=$(($port + 1))
	sleep 10
done
echo "IPERF test completed" >> ~/teststatus.txt

#formatting logs into csv file:
mkdir $logs_dir/csvs
cd $logs_dir/
options=(`ls */*iperf.log | sed s/\.log//`)
echo "CSV test started" >> ~/teststatus.txt
count=0
while [ "x${options[count]}" != "x" ]
do
	echo "${options[count]}"
	cat ${options[count]}.log | grep SUM > /dev/null
	if [ $? -ne 0 ]; then
		cat ${options[count]}.log | grep sec | awk '!($1="")' | awk '!($1="")' | awk '{$1=$1}1' OFS=","| sed s/\(// | sed s/\)//|sed s/-/,/ | sed s/%//>$logs_dir/csvs/`basename ${options[count]}`.csv
	else
		cat ${options[count]}.log | grep SUM | awk '!($1="")' | awk '{$1=$1}1' OFS=","| sed s/\(// | sed s/\)//|sed s/-/,/ | sed s/%//>$logs_dir/csvs/`basename ${options[count]}`.csv
	fi
	count=$(( $count + 1 )) 
done
echo "CSV test completed" >> ~/teststatus.txt
cd ~
tar -cvf logs.tar logs > /dev/null
echo "PERF test completed" >> ~/teststatus.txt

exit 0
