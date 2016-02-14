#!/bin/bash
#
# This script converts Sysbench output file into csv format.
# Author	: Srikanth M
# Email	: v-srm@microsoft.com
####

syslog_file_name=$1

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <sysbench-output.log>" >&2
  exit 1
fi

if [ ! -f $syslog_file_name ]; then
    echo "$1: File not found!"
	exit 1
fi

csv_file=`echo $syslog_file_name | sed s/\.log\.txt//`
csv_file=$csv_file.csv
echo $csv_file

TEMP_DIR='temp'
mkdir $TEMP_DIR

echo "Iteration,StartTime,Threads,FileSize,BlockSize,IOMode,TestType,ReadOperations,WriteOperations,OtherOperations,TotalOperations,ReadBytes,WriteBytes,TotalBytes,Throughput,IOPS,TotalTime(s),TotalEvents,MinLatency(ms),AvgLatency(ms),MaxLatency(ms), 95% PercentileLatency(ms)" > $csv_file

res_AvgLatency=(`cat $syslog_file_name | grep "avg:" | awk '{print $2}' | sed s/ms//`)
res_BlockSize=(`cat $syslog_file_name | grep "Block size "| sed "s/Block size //"`)
res_FileSize=(`cat $syslog_file_name | grep "total file size"| sed "s/ total file size//"`)
res_IOMode=(`cat $syslog_file_name | grep "Using .* I/O mode" | sed 's/Using \(.*\) I\/O mode/\1/'`)
res_IOPS=(`cat $syslog_file_name | grep "Requests/sec executed"| awk '{print $1}'`)
res_Iteration=(`cat $syslog_file_name | grep "iteration "| awk '{print $3}'`)
res_MaxLatency=(`cat $syslog_file_name | grep "max:" | awk '{print $2}' | sed s/ms//`)
res_MinLatency=(`cat $syslog_file_name | grep "min:" | awk '{print $2}' | sed s/ms//`)
res_OtherOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $7}'`)
res_PercentileLatency=(`cat $syslog_file_name | grep "approx.  95 percentile:" | awk '{print $4}' | sed s/ms//`)
res_ReadBytes=(`cat $syslog_file_name | grep "Read "| awk '{print $2}'`)
res_ReadOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $3}'`)
res_StartTime=(`cat $syslog_file_name | grep "iteration "| awk '{print $12 ":" $13 ":" $14}'`)
res_TestType=(`cat $syslog_file_name | grep "iteration"| awk  '{print $5}'| sed s/,//`)
res_Throughput=(`cat $syslog_file_name | grep "Read " | awk '{print $8}' | sed s/\(//| sed s/\)//`)
res_TotalEvents=(`cat $syslog_file_name | grep "total number of events:"  | awk '{print $5}'`)
res_TotalOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $10}'`)
res_TotalTime=(`cat $syslog_file_name | grep "total time: " | awk '{print $3}'| sed s/s//`)
res_WriteBytes=(`cat $syslog_file_name | grep "Read "| awk '{print $4}'`)
res_WriteOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $5}'`)
res_threads=(`cat $syslog_file_name | grep "Number of threads:" | sed "s/Number of threads: //"`)
res_TotalBytes=(`cat $syslog_file_name | grep "Read "| awk '{print $7}'`)

count=0

while [ "x${res_Iteration[$count]}" != "x" ]
do
	echo  ${res_Iteration[$count]}
	echo "${res_Iteration[$count]}, ${res_StartTime[$count]}, ${res_threads[$count]}, ${res_FileSize[$count]}, ${res_BlockSize[$count]}, ${res_IOMode[$count]},  ${res_TestType[$count]}, ${res_ReadOperations[$count]}, ${res_WriteOperations[$count]}, ${res_OtherOperations[$count]}, ${res_TotalOperations[$count]}, ${res_ReadBytes[$count]}, ${res_WriteBytes[$count]}, ${res_TotalBytes[$count]}, ${res_Throughput[$count]}, ${res_IOPS[$count]}, ${res_TotalTime[$count]}, ${res_TotalEvents[$count]}, ${res_MinLatency[$count]}, ${res_AvgLatency[$count]}, ${res_MaxLatency[$count]}, ${res_PercentileLatency[$count]}, "  >> $csv_file
	((count++))
done

sed -i  -e  "s/rndrd/Random read/" $csv_file
sed -i  -e  "s/seqrd/Sequential read/" $csv_file
sed -i  -e  "s/seqrewr/Sequential write/" $csv_file
sed -i  -e  "s/rndwr/Random write/" $csv_file

echo "Output csv file: $csv_file created successfully." >> $syslog_file_name
echo "LOGPARSER COMPLETED." >> $syslog_file_name

rm -rf $TEMP_DIR
