#!/bin/bash
#
# This script converts Network performance output files into csv files.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#
format_bites(){
	temp_size=$1
	temp_units="Gbps"
	temp_size=`echo $temp_size 1000| awk '{printf "%.3f \n", $1/$2}'`
	temp_size=`echo $temp_size 1000| awk '{printf "%.3f \n", $1/$2}'`
	echo $temp_size,$temp_units
}

gen_csv(){
	input_file=$1
	number_of_connections=$2

	output_file=`echo $input_file |sed s/\.log$/\.csv/`
	top_array_file=`echo $output_file |sed s/sar/top/`
	conn_array_file=`echo $output_file |sed s/sar/connections/`
	cpu_vmstat_file=`echo $input_file |sed s/sar/vmstat/`

	rx_array_file=$input_file-rxkBps.log
	tx_array_file=$input_file-txkBps.log
	cpu_vmstat_array_file=$input_file-cpu-vmstat.log

	cat $cpu_vmstat_file | grep -v [a-z]| awk '{print 100 - $15}' > $cpu_vmstat_array_file 
	cat $input_file | grep eth0 | awk '{print $6}' > $rx_array_file
	cat $input_file | grep eth0 | awk '{print $7}' > $tx_array_file

	rx_array=(`cat $rx_array_file`)
	tx_array=(`cat $tx_array_file`)
	top_array=(`cat $top_array_file`)
	conn_array=(`cat $conn_array_file`)
	cpu_array=(`cat $cpu_vmstat_array_file`)

	length=$((${#rx_array[@]}-1))
	count=0
	sum=0
	rx_sum=0
	tx_sum=0

	res_kernel_version=(`cat $input_file | grep "Linux.*x86_64.*GNU"| awk '{print $3}'`)
	res_total_cpu_cores=(`cat $input_file | grep "Number of CPU cores" | awk '{print $5}'`)
	res_LIS_version=(`cat $input_file | grep "^version:"| awk '{print $2}'`)
	res_Host_version=(`cat $input_file | grep "Host Build Version" | awk '{print $4}'`)
	res_total_memory=(`cat $input_file |grep "^Memory" | awk '{print $2}'`)
	
	echo "" > $output_file
	echo ",Kernel version,"$res_kernel_version >> $output_file
	echo ",Total CPU cores,"$res_total_cpu_cores >> $output_file
	echo ",Memory,"$res_total_memory >> $output_file
	echo ",LIS Version,"$res_LIS_version >> $output_file
	echo ",Host Version,"$res_Host_version >> $output_file
	echo "" >> $output_file

	echo Rx Throughput,Units,TxThroughput,Units,Total,Units,,Time,ActiveConnection,,Time,CPU Usage >> $output_file

	for i in `seq 1 $length`;
	do
		Tx_bits=`echo 8 ${tx_array[count]}| awk '{printf "%.3f \n", $1*$2}'`
		Rx_bits=`echo 8 ${rx_array[count]}| awk '{printf "%.3f \n", $1*$2}'`

		Tx_data=`format_bites $Tx_bits`
		Rx_data=`format_bites $Rx_bits`
		Total_bits=`echo $Tx_bits $Rx_bits| awk '{printf "%.3f \n", $1+$2}'`

		Total_data=`format_bites $Total_bits`
		conn_info=${conn_array[count]}
		if [ "x$conn_info" == "x" ]
		then
			conn_info=","
		fi

		echo $Rx_data,$Tx_data,$Total_data,,$conn_info,,$count,${cpu_array[count]}>> $output_file
		rx_sum=`echo $rx_sum ${rx_array[count]}| awk '{printf "%.3f \n", $1+$2}'`
		tx_sum=`echo $tx_sum ${tx_array[count]}| awk '{printf "%.3f \n", $1+$2}'`
		((count++))
	done
	sum=`echo $tx_sum $rx_sum| awk '{printf "%.3f \n", $1+$2}'`
	avg=`python -c "print $sum*8/($length*1000*1000)"`
	echo $number_of_connections - $avg
	rm -rf $rx_array_file $tx_array_file $cpu_vmstat_array_file.log
}

logs_folder=$1
for number_of_connections in 1 2 4 8 16 32 64 128 256 512 1024 2000 3000 4000 5000 6000
do
	gen_csv $logs_folder/$number_of_connections/$number_of_connections-sar.log $number_of_connections&
done
wait
logs_folder=`echo $logs_folder| sed 's/\/$//'`
tar -cvf $logs_folder.tar $logs_folder/
echo "completed!"
