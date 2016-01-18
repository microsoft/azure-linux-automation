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

cat $syslog_file_name | grep "iteration "| awk '{print $3}' > $TEMP_DIR/res_Iteration.txt
cat $syslog_file_name | grep "iteration "| awk '{print $12 ":" $13 ":" $14}' > $TEMP_DIR/res_StartTime.txt
cat $syslog_file_name | grep "Number of threads:" | sed "s/Number of threads: //" > $TEMP_DIR/res_threads.txt
cat $syslog_file_name | grep "total file size"| sed "s/ total file size//" > $TEMP_DIR/res_FileSize.txt
cat $syslog_file_name | grep "Block size "| sed "s/Block size //" > $TEMP_DIR/res_BlockSize.txt
cat $syslog_file_name | grep "Using .* I/O mode" | sed 's/Using \(.*\) I\/O mode/\1/' > $TEMP_DIR/res_IOMode.txt
cat $syslog_file_name | grep "iteration"| awk  '{print $5}'| sed s/,// > $TEMP_DIR/res_TestType.txt
cat $syslog_file_name | grep "Operations performed:"| awk  '{print $3}'> $TEMP_DIR/res_ReadOperations.txt
cat $syslog_file_name | grep "Operations performed:"| awk  '{print $5}'> $TEMP_DIR/res_WriteOperations.txt
cat $syslog_file_name | grep "Operations performed:"| awk  '{print $7}'> $TEMP_DIR/res_OtherOperations.txt
cat $syslog_file_name | grep "Operations performed:"| awk  '{print $10}' > $TEMP_DIR/res_TotalOperations.txt
cat $syslog_file_name | grep "Read "| awk '{print $2}' > $TEMP_DIR/res_ReadBytes.txt
cat $syslog_file_name | grep "Read "| awk '{print $4}' > $TEMP_DIR/res_WriteBytes.txt
cat $syslog_file_name | grep "Read "| awk '{print $7}' > $TEMP_DIR/res_TotalBytes.txt
cat $syslog_file_name | grep "Read " | awk '{print $8}' | sed s/\(//| sed s/\)// > $TEMP_DIR/res_Throughput.txt
cat $syslog_file_name | grep "Requests/sec executed"| awk '{print $1}'> $TEMP_DIR/res_IOPS.txt
cat $syslog_file_name | grep "total time: " | awk '{print $3}'| sed s/s// > $TEMP_DIR/res_TotalTime.txt
cat $syslog_file_name | grep "total number of events:"  | awk '{print $5}' > $TEMP_DIR/res_TotalEvents.txt
cat $syslog_file_name | grep "min:" | awk '{print $2}' | sed s/ms// > $TEMP_DIR/res_MinLatency.txt
cat $syslog_file_name | grep "avg:" | awk '{print $2}' | sed s/ms// > $TEMP_DIR/res_AvgLatency.txt
cat $syslog_file_name | grep "max:" | awk '{print $2}' | sed s/ms// > $TEMP_DIR/res_MaxLatency.txt
cat $syslog_file_name | grep "approx.  95 percentile:" | awk '{print $4}' | sed s/ms// > $TEMP_DIR/res_PercentileLatency.txt
echo "Iteration,StartTime,Threads,FileSize,BlockSize,IOMode,TestType,ReadOperations,WriteOperations,OtherOperations,TotalOperations,ReadBytes,WriteBytes,TotalBytes,Throughput,IOPS,TotalTime(s),TotalEvents,MinLatency(ms),AvgLatency(ms),MaxLatency(ms), 95% PercentileLatency(ms)" > $csv_file

res_AvgLatency=(`cat $TEMP_DIR/res_AvgLatency.txt`)
res_BlockSize=(`cat $TEMP_DIR/res_BlockSize.txt`)
res_FileSize=(`cat $TEMP_DIR/res_FileSize.txt`)
res_IOMode=(`cat $TEMP_DIR/res_IOMode.txt`)
res_IOPS=(`cat $TEMP_DIR/res_IOPS.txt`)
res_Iteration=(`cat $TEMP_DIR/res_Iteration.txt`)
res_MaxLatency=(`cat $TEMP_DIR/res_MaxLatency.txt`)
res_MinLatency=(`cat $TEMP_DIR/res_MinLatency.txt`)
res_OtherOperations=(`cat $TEMP_DIR/res_OtherOperations.txt`)
res_PercentileLatency=(`cat $TEMP_DIR/res_PercentileLatency.txt`)
res_ReadBytes=(`cat $TEMP_DIR/res_ReadBytes.txt`)
res_ReadOperations=(`cat $TEMP_DIR/res_ReadOperations.txt`)
res_StartTime=(`cat $TEMP_DIR/res_StartTime.txt`)
res_TestType=(`cat $TEMP_DIR/res_TestType.txt`)
res_Throughput=(`cat $TEMP_DIR/res_Throughput.txt`)
res_TotalEvents=(`cat $TEMP_DIR/res_TotalEvents.txt`)
res_TotalOperations=(`cat $TEMP_DIR/res_TotalOperations.txt`)
res_TotalTime=(`cat $TEMP_DIR/res_TotalTime.txt`)
res_WriteBytes=(`cat $TEMP_DIR/res_WriteBytes.txt`)
res_WriteOperations=(`cat $TEMP_DIR/res_WriteOperations.txt`)
res_threads=(`cat $TEMP_DIR/res_threads.txt`)
res_TotalBytes=(`cat $TEMP_DIR/res_TotalBytes.txt`)
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

echo "Output csv file: $csv_file created successfully."
echo "LOGPARSER COMPLETED."

rm -rf $TEMP_DIR
