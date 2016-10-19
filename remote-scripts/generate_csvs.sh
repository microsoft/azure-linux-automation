#!/bin/bash
#
# This script converts Network performance output files into csv files.
# Author: Srikanth Myakam
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
	summary_file=$3

	output_file=`echo $input_file |sed s/\.log$/\.csv/`
	top_array_file=`echo $output_file |sed s/sar/top/`
	conn_array_file=`echo $output_file |sed s/sar/connections/`
	cpu_vmstat_file=`echo $input_file |sed s/sar/vmstat/`

	rx_pcks_array_file=$input_file-rxpcks.log
	tx_pcks_array_file=$input_file-txpcks.log
	rx_array_file=$input_file-rxkBps.log
	tx_array_file=$input_file-txkBps.log
	cpu_vmstat_array_file=$input_file-cpu-vmstat.log

	cat $cpu_vmstat_file | grep -v [a-z]| awk '{print 100 - $15}' > $cpu_vmstat_array_file
	cat $input_file | grep eth0 | awk '{print $4}' > $rx_pcks_array_file
	cat $input_file | grep eth0 | awk '{print $5}' > $tx_pcks_array_file
	cat $input_file | grep eth0 | awk '{print $6}' > $rx_array_file
	cat $input_file | grep eth0 | awk '{print $7}' > $tx_array_file

	rx_pcks_array=(`cat $rx_pcks_array_file`)
	tx_pcks_array=(`cat $tx_pcks_array_file`)
	rx_array=(`cat $rx_array_file`)
	tx_array=(`cat $tx_array_file`)
	top_array=(`cat $top_array_file`)
	conn_array=(`cat $conn_array_file`)
	cpu_array=(`cat $cpu_vmstat_array_file`)

	length=$((${#rx_array[@]}-1))
	count=0
	sum=0
	rx_pcks_sum=0
	tx_pcks_sum=0
	rx_sum=0
	tx_sum=0
	cpu_sum=0

	echo Rx Throughput,Units,TxThroughput,Units,Total,Units,,Time,ActiveConnection,Rx packets,Tx packets,,Time,CPU Usage >> $output_file

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

		echo $Rx_data,$Tx_data,$Total_data,,$conn_info,${rx_pcks_array[count]},${tx_pcks_array[count]},,$count,${cpu_array[count]}>> $output_file
		rx_pcks_sum=`echo $rx_pcks_sum ${rx_pcks_array[count]}| awk '{printf "%.3f \n", $1+$2}'`
		tx_pcks_sum=`echo $tx_pcks_sum ${tx_pcks_array[count]}| awk '{printf "%.3f \n", $1+$2}'`
		rx_sum=`echo $rx_sum ${rx_array[count]}| awk '{printf "%.3f \n", $1+$2}'`
		tx_sum=`echo $tx_sum ${tx_array[count]}| awk '{printf "%.3f \n", $1+$2}'`
		cpu_sum=`echo $cpu_sum ${cpu_array[count]}| awk '{printf "%.3f \n", $1+$2}'`

		((count++))
	done
	sum=`echo $tx_sum $rx_sum| awk '{printf "%.3f \n", $1+$2}'`
	pcks_sum=`python -c "print '%d' % ($tx_pcks_sum+$rx_pcks_sum)"`
	avg_thrpt=`python -c "print '%.2f' %  ($sum*8/($length*1000*1000))"`
	avg_cpu=`python -c "print '%d' % ($cpu_sum/$length)"`

	echo $number_of_connections,$avg_thrpt,$pcks_sum,$avg_cpu >> $summary_file
	rm -rf $rx_array_file $tx_array_file $cpu_vmstat_array_file.log
}

logs_folder=$1
#summary_file=$logs_folder/summary_file_`hostname`.csv
summary_file=$logs_folder/summary_file_`hostname`.csv
echo "" > $summary_file
echo "Connections,Avg Throughput,Total packets,Avg CPU" > $summary_file
for number_of_connections in 1 2 4 8 16 32 64 128 256 512 1024
do
	echo "Converting $number_of_connections logs.."
	gen_csv $logs_folder/$number_of_connections/$number_of_connections-sar.log $number_of_connections $summary_file&
done
wait

mkdir -p $logs_folder/csv_files/
for number_of_connections  in 1 2 4 8 16 32 64 128 256 512 1024
do
	mv $logs_folder/$number_of_connections/$number_of_connections-sar.csv $logs_folder/csv_files/
done

cat $summary_file | sort -n > $summary_file.tmp
mv $summary_file.tmp $summary_file
logs_folder=`echo $logs_folder| sed 's/\/$//'`
tar -czf $logs_folder.tar.gz $logs_folder/
echo "Completed!"
