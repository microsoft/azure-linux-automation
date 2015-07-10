#!/bin/bash
nc=$1
duration=$2
echo "Starting iperf client in `hostname`"
echo "Num of Connections: $nc"
total_no_vms=`cat hostnames.txt | wc -l`
nc_vm=$(($nc/$((($total_no_vms-1)*2))))
echo "Num of Connections per VM $nc_vm"
my_hostname=`hostname`
my_vm_number=`cat hostnames.txt | grep -n $my_hostname$| sed s/:.*//`
hostnames=(`cat hostnames.txt`)
#start sar with nc and time in its name
echo "stating sar in client `hostname`"
sarlog=$nc-`hostname`
bash collect-stats.sh $duration $sarlog &
for server_vm_number in `seq 0 $((${#hostnames[@]}-1))` 
do
	if [ ${hostnames[$server_vm_number]} != $my_hostname ]
	then		
		number_of_connections=$nc_vm
		echo $server_vm_number:$my_vm_number
		port_number=$((8001+($my_vm_number-1)*6))
		while [ $number_of_connections -gt 64 ]; do
			number_of_connections=$(($number_of_connections-64))
			echo "iperf3 -c ${hostnames[$server_vm_number]} -p $port_number -P 64 -t $duration >> `hostname`-clientlog.txt &" # /dev/null  &
			iperf3 -c ${hostnames[$server_vm_number]} -p $port_number -P 64 -t $duration > /dev/null &
			port_number=$((port_number+1))
		done
		echo "iperf3 -c ${hostnames[$server_vm_number]} -p $port_number -P $number_of_connections -t $duration >> `hostname`-clientlog.txt &" #/dev/null"
		iperf3 -c ${hostnames[$server_vm_number]} -p $port_number -P $number_of_connections -t $duration > /dev/null &
	fi
done
iperf_count=`pgrep iperf3 | wc -l`
if [ $iperf_count -gt 100 ]; then
	echo "iperf clients is running in `hostname`"
else
	echo "iperf clients is not running in `hostname`"
fi

exit 0
