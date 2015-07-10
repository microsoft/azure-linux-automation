#!/bin/bash
#Prerequisites: iperf3, sysstat(for sar), dos2unix

user=$1
passwd=$2
server_file=$3
client_file=$4
num_of_connections=$5
duration=$6
hostnames=(`cat hostnames.txt`)
count=0

mainlog="$num_of_connections"_main_log.txt
serverlog="$num_of_connections"_server_status.txt
clientlog="$num_of_connections"_client_status.txt
[ -f $mainlog ] && rm -rf $mainlog
[ -f $serverlog ] && rm -rf $serverlog
[ -f $clientlog ] && rm -rf $clientlog
#Process to start server..
while [ "x${hostnames[count]}" != "x" ]
do
	echo ${hostnames[count]} >> $mainlog
	if [ `hostname` == ${hostnames[$count]} ]; then
		echo "start server in localhost" >> $mainlog
		bash $server_file >> $serverlog
	else
		echo "copying server file to ${hostnames[$count]} and start server" >> $mainlog
		sshpass -p $passwd scp -o StrictHostKeyChecking=no $server_file $client_file hostnames.txt collect-stats.sh $user@${hostnames[$count]}:/home/$user
		sshpass -p $passwd ssh -o StrictHostKeyChecking=no $user@${hostnames[$count]} "bash $server_file" >> $serverlog
	fi
	count=$(( $count + 1 ))
done

#Process to start client..
server_status=`cat $serverlog | grep "iperf server is running" | wc -l`
echo "Server status: $server_status" >> $mainlog
if [ $server_status == `cat hostnames.txt | wc -l` ]; then
	echo "iperf server is running in all machines.." >> $mainlog
	count=0
	while [ "x${hostnames[count]}" != "x" ]
	do
		echo ${hostnames[count]} >> $mainlog
		if [ `hostname` == ${hostnames[$count]} ]; then
			echo "starting client in localhost" >> $mainlog
				bash $client_file $num_of_connections $duration >> $clientlog &
		else
			echo "starting client in ${hostnames[$count]}" >> $mainlog
				sshpass -p $passwd ssh -o StrictHostKeyChecking=no $user@${hostnames[$count]} "bash $client_file $num_of_connections $duration" >> $clientlog &
		fi
		count=$(( $count + 1 ))
	done
else
	echo "iperf server is not running, check server status.." >> $mainlog
	echo "Mesh Network test Failed"
	exit 10
fi
echo "iperf tests are running please wait"
sleep $(( $duration + 120 ))
count=0
iperf_status=0
while [ "x${hostnames[count]}" != "x" ]
do
	echo "verifying iperf client status in ${hostnames[$count]}" >> $mainlog
	iperfc_count=`sshpass -p $passwd ssh -o StrictHostKeyChecking=no $user@${hostnames[$count]} "pgrep iperf3| wc -l"`
	if [ $iperfc_count != 100 ]; then
		echo "IPERF client status in ${hostnames[$count]}:$iperfc_count" >> $mainlog
		iperf_status=$(( $iperf_status + 1 ))
	else
		echo "Iperf test completed in ${hostnames[$count]}" >> $mainlog
	fi
	count=$(( $count + 1 ))
done
if [ $iperf_status != 0 ]; then
	echo "Mesh Network test Failed"
else
	echo "Mesh Network test Success"
	
#collecting logs..
count=0
while [ "x${hostnames[count]}" != "x" ]
do
	echo ${hostnames[count]} >> $mainlog
	if [ `hostname` == ${hostnames[$count]} ]; then
		echo "copying localhost logs" >> $mainlog
	else
		echo "copying logs from ${hostnames[$count]} to localhost " >> $mainlog
		sshpass -p $passwd scp -o StrictHostKeyChecking=no $user@${hostnames[$count]}:/home/$user/$num_of_connections"-*.log" /home/$user/  >> $mainlog
	fi
	count=$(( $count + 1 ))
done

fi

exit 0
