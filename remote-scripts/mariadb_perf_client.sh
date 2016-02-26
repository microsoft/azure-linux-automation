#!/bin/bash
# MariaDB performance using sysbench client.
# Packages needed: sysbench bc
# usage::-
# nohup bash sysbench-mariadb-perf-test.sh vm_loginuser  mariadb_server &
# or
#./sysbench-mariadb-perf-test.sh vm_loginuser  mariadb_server &
#
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
#
###########################################################################


#set -u
#set -x

if [[ $# == 3 ]]
then
	username=$1
	user_password=$2
	mariadb_server=$3
else
	echo "Usage: bash $0 <vm_loginuser> <vm_loginpasswd> <mariadb_server IP>"
	exit -1
fi

mariadb_user="root" 
mariadb_passwd="mariadb_passwd"
perf_db="iperf_db"

code_path="/home/$username/code"
LOGDIR="${code_path}/mysql_perf_log"
mv $LOGDIR $LOGDIR-$(date +"%m%d%Y-%H%M%S")/
mkdir $LOGDIR
LOGFILE="${LOGDIR}/mysql_perf_sysbench.log"
touch $LOGFILE
tail -f $LOGFILE &

. $code_path/azuremodules.sh

echo "Creating code folder on server VM" >> $LOGFILE
remote_exec -user $username -passwd $user_password -host $mariadb_server "mkdir $code_path"  >> $LOGFILE
echo "Uploading files to server" >> $LOGFILE
remote_copy -user $username -passwd $user_password -host $mariadb_server -filename ${code_path}/azuremodules.sh -remote_path $code_path -cmd "put" >> $LOGFILE
remote_copy -user $username -passwd $user_password -host $mariadb_server -filename ${code_path}/mariadb_perf_server_conf.sh -remote_path $code_path -cmd "put" >> $LOGFILE
echo "Verifying MYSQL server instances on Server VM"  >> $LOGFILE
remote_exec -user $username -passwd $user_password -host $mariadb_server "echo $user_password | sudo -S bash $code_path/mariadb_perf_server_conf.sh $username" >> $LOGFILE
return_value=`remote_exec -user $username -passwd $user_password -host $mariadb_server "netstat -napt| grep ':3306 '|wc -l"`

if [[ $return_value == 0 ]]
then
	echo "Server configuration failued" >> $LOGFILE
	echo "MYSQL Perf TEST ABORTED" >> $LOGFILE
	exit -1
else
	echo "DB server is running" >> $LOGFILE
fi

install_package "sysbench" >> $LOGFILE
install_package "mysql-client*" >> $LOGFILE

FILEIO=" --test=oltp --db-driver=mysql --mysql-db=$perf_db --mysql-host=$mariadb_server --mysql-user=$mariadb_user --mysql-password=$mariadb_passwd "

echo "uname: -------------------------------------------------" >> $LOGFILE
uname -a 2>&1 >> $LOGFILE
echo "LIS version: --------------------------------------------" >> $LOGFILE
modinfo hv_vmbus 2>&1 >> $LOGFILE
echo "----------------------------------------------------------" >> $LOGFILE
echo "Number of CPU cores:" `nproc` >> $LOGFILE
echo "Memory:" `free -h| grep Mem| awk '{print $2}'` >> $LOGFILE
echo "Host Build Version:" `dmesg | grep "Host Build" | sed "s/.*Host Build://"| awk '{print  $1}'| sed "s/;//"`  >> $LOGFILE

runtime=300
threads=990
table_size=10000000

echo "Test log created at: ${LOGFILE}"
echo "===================================== Starting Run $(date +"%x %r %Z") ================================" >> $LOGFILE

chmod 666 $LOGFILE
echo "Preparing Files: $FILEIO" >> $LOGFILE
# Remove any old files from prior runs (to be safe), then prepare a set of new files.
sysbench $FILEIO cleanup

time sysbench $FILEIO --oltp-table-size=$table_size prepare 2>&1 >> $LOGFILE
echo "=== End Preparation  $(date +"%x %r %Z") ===" >> $LOGFILE
mysql -u root -p$mariadb_passwd --host=$mariadb_server -e "SET GLOBAL max_connections = 5000;"
echo "------------------------------- mysql_perf, ${table_size} table_size, ${threads} threads, $runtime seconds ------------------ $(date +"%x %r %Z") ---" >> $LOGFILE
sysbench $FILEIO --max-time=$runtime --max-requests=0 --oltp-table-size=$table_size --num-threads=$threads run >> $LOGFILE

echo "===================================== Completed Run $(date +"%x %r %Z") script generated 2/9/2015 4:24:44 PM ================================" >> $LOGFILE
sysbench $FILEIO cleanup >> $LOGFILE

compressedFileName="mariadb-db-test"$(date +"%m%d%Y-%H%M%S")".tar.gz"
echo "Please wait...Compressing all results to ${compressedFileName}..."
tar -cvf $compressedFileName $LOGDIR/ 2>&1 > /dev/null

test_run=`tail -150 $LOGFILE | grep "Test execution summary:"`

if [[ $test_run != "" ]]
then
	echo "MYSQL_Perf_TEST_COMPLETED" >> $LOGFILE
else
	echo "MYSQL_Perf_TEST_ABORTED" >> $LOGFILE
fi

echo "Test logs are located at ${LOGDIR}"
##
