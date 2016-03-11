#!/bin/bash
# 
# usage::-
# nohup bash sysbench-full-io-test.sh &
# or
#./sysbench-full-io-test.sh &
#
# For any info contact v-avchat@microsoft.com

set -u
set -x
#export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/oem/bin:/usr/share/oem/python/bin:/opt/bin

FILEIO="--test=fileio --file-total-size=134G --file-extra-flags=dsync --file-fsync-freq=0"
#FILEIO="--test=fileio --file-total-size=134G "

####################################
#All run config set here
#

if [[ $# == 1 ]]
then
	username=$1
else
	echo "Usage: bash $0 <vm_loginuser>"
	exit -1
fi
code_path="/home/$username/code"
. $code_path/azuremodules.sh
mv $code_path/sysbenchlog/ $code_path/sysbenchlog-$(date +"%m%d%Y-%H%M%S")/
sleep 5
mkdir $code_path/sysbenchlog
LOGDIR="${code_path}/sysbenchlog"
LOGFILE="${LOGDIR}/sysbench.log.txt"

if [[ `which sysbench` == "" ]]
then
	install_package sysbench
	check_exit_status "Sysbench package installation" exit
fi

if [[ `which iostat` == "" ]]
then
	install_package sysstat
	check_exit_status "Sysstat package installation"
fi

echo "uname: -------------------------------------------------" > $LOGFILE
uname -a 2>&1 >> $LOGFILE
echo "LIS version: --------------------------------------------" >> $LOGFILE
modinfo hv_vmbus 2>&1 >> $LOGFILE
echo "----------------------------------------------------------" >> $LOGFILE
echo "Number of CPU cores" `nproc` >> $LOGFILE
echo "Memory" `free -h| grep Mem| awk '{print $2}'` >> $LOGFILE
echo "Host Build Version" `dmesg | grep "Host Build" | sed "s/.*Host Build://"| awk '{print  $1}'| sed "s/;//"`  >> $LOGFILE
echo "Data disks attached" `fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$"| wc -l`  >> $LOGFILE

iteration=0
ioruntime=300
maxThread=1024
maxIo=32

#All possible values for file-test-mode are rndrd rndwr rndrw seqrd seqwr seqrewr
modes='rndrd rndwr rndrw seqrd seqrewr'
#modes='rndrd rndwr rndrw seqrd seqwr seqrewr'

startThread=1
startIO=4
####################################

echo "Test log created at: ${LOGFILE}"
echo "===================================== Starting Run $(date +"%x %r %Z") ================================"
echo "===================================== Starting Run $(date +"%x %r %Z") script generated 2/9/2015 4:24:44 PM ================================" >> $LOGFILE

chmod 666 $LOGFILE
echo "Preparing Files: $FILEIO"
echo "Preparing Files: $FILEIO" >> $LOGFILE
# Remove any old files from prior runs (to be safe), then prepare a set of new files.
sysbench $FILEIO cleanup
echo "--- Disk Usage Before Generating New Files ---" >> $LOGFILE
df >> $LOGFILE
sysbench $FILEIO prepare
echo "--- Disk Usage After Generating New Files ---" >> $LOGFILE
df >> $LOGFILE
echo "=== End Preparation  $(date +"%x %r %Z") ===" >> $LOGFILE

####################################
#Trigger run from here
for testmode in $modes; do
	io=$startIO
	while [ $io -le $maxIo ]
	do
		Thread=$startThread
		while [ $Thread -le $maxThread ]
		do
			iostatfilename="${LOGDIR}/iostat-sysbench-${testmode}-${io}K-${Thread}.txt"
			nohup iostat -x 5 -t -y > $iostatfilename &
			echo "-- iteration ${iteration} ----------------------------- ${testmode}, ${io}K, ${Thread} threads, 5 minutes ------------------ $(date +"%x %r %Z") ---" >> $LOGFILE
			sysbench $FILEIO --file-test-mode=$testmode --file-block-size=${io}"K" --max-requests=0 --max-time=$ioruntime --num-threads=$Thread run >> $LOGFILE
			iostatPID=`ps -ef | awk '/iostat/ && !/awk/ { print $2 }'`
			kill -9 $iostatPID
			Thread=$(( Thread*2 ))
		done
		io=$(( io*2 ))
	done
	iteration=$(( iteration+1 ))
done
####################################
echo "===================================== Completed Run $(date +"%x %r %Z") script generated 2/9/2015 4:24:44 PM ================================" >> $LOGFILE
sysbench $FILEIO cleanup >> $LOGFILE


compressedFileName="SysbenchIOTest"$(date +"%m%d%Y-%H%M%S")".tar.gz"
echo "Please wait...Compressing all results to ${compressedFileName}..."
tar -cvzf $compressedFileName $LOGDIR/*.txt
mv $compressedFileName $LOGDIR/$compressedFileName
####################################
find_log_diff () {
LogMax=`(echo "l($1)/l(2)" | bc -l| sed 's/\..*$//')`
LogMin=`(echo "l($2)/l(2)" | bc -l| sed 's/\..*$//')`
diff=$(($LogMax - $LogMin + 1))
echo $diff
}

IO_difference=`find_log_diff $maxIo $startIO`
Thread_difference=`find_log_diff $maxThread $startThread`
Total_Modes=`echo $modes| wc -w`
total_iterations=$(($IO_difference * $Thread_difference *Total_Modes - 1))
echo $total_iterations

last_iteration=`tail -150 $LOGFILE | grep iteration| tail -1 | awk '{print $3}'`

if [ $last_iteration == $total_iterations ]
then
	echo "SYSBENCH TEST COMPLETED" >> $LOGFILE
	echo "SYSBENCH TEST COMPLETED"
else
	echo "SYSBENCH TEST ABORTED" >> $LOGFILE
	echo "SYSBENCH TEST ABORTED"
fi

####################################
bash $code_path/sysbench-log-parser.sh $LOGFILE

echo "Test logs are located at ${LOGDIR}"

vm_bus_ver=`modinfo hv_vmbus| grep ^version| awk '{print $2}'`
tar -cvf $code_path/logs-`hostname`-`uname -r`-$vm_bus_ver.tar $code_path/*
