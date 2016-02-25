#!/bin/bash
#
# This script does the following:
# 1. Prepares the RAID with all the data disks attached 
# 2. Places an entry for the created RAID in /etc/fstab.
# 3. Configures mariadb server for sysbench performance test.
# Usage:-
# nohup bash mariadb_perf_server_conf.sh vm_loginuser &
#
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
#
###########################################################################

if [[ $# == 1 ]]
then
	username=$1
else
	echo "Usage: bash $0 <username>"
	exit -1
fi
code_path="/home/$username/code"
. $code_path/azuremodules.sh

function install_mysql_server () 
{
	if [[ `detect_linux_ditribution` == "ubuntu" ]]
	then
		mariadb_passwd=$1
		export DEBIAN_FRONTEND=noninteractive
		echo mysql-server mysql-server/root_password select $mariadb_passwd | debconf-set-selections
		echo mysql-server mysql-server/root_password_again select $mariadb_passwd| debconf-set-selections
		apt-get install -y  --force-yes mysql-server
		check_exit_status "Installation of mysql-server" exit
	else
		install_package mariadb-server
		check_exit_status "Installation of mariadb" exit
	fi
}

format="ext4"
mountdir="/dataIOtest"
deviceName="/dev/md1"
LOGFILE="${code_path}/mariadb_perftest.log.txt"
mariadb_passwd="mariadb_passwd"
perf_db="iperf_db"
mysql_cnf_file=""


install_mysql_server $mariadb_passwd

if [[ -f /etc/mysql/mariadb.conf.d/mysqld.cnf ]]; then
	mysql_cnf_file=/etc/mysql/mariadb.conf.d/mysqld.cnf
elif [[ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]]; then
	mysql_cnf_file=/etc/mysql/mysql.conf.d/mysqld.cnf
elif [[ -f /etc/mysql/my.cnf ]]; then
	mysql_cnf_file=/etc/mysql/my.cnf
elif [[ -f /etc/my.cnf ]]; then
	mysql_cnf_file=/etc/my.cnf 
else
	echo "Cannnot find mariadb configuration file check the installation"
	exit -1
fi

echo "IO test setup started.." > $LOGFILE

# Verify if there are any unsed disks and creat raid using them and move the db folder to there
list=(`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$" `)

if [[ ${#list[@]} -gt 0 ]]
then
	create_raid_and_mount $deviceName $mountdir $format >> $LOGFILE
	df -hT >> $LOGFILE
	echo "## Configuring mariadb" >> $LOGFILE
	mysql_datadir="$mountdir/mysql"
	mkdir $mysql_datadir
	chmod 777 -R $mysql_datadir
	cp -rf /var/lib/mysql/* $mysql_datadir
#	sed -i  "s#datadir.*#datadir         = $mysql_datadir#" $mysql_cnf_file
	sed -i  "s/\(.(*datadir.*\)/#\1/" $mysql_cnf_file
	echo "datadir         = $mysql_datadir" >> $mysql_cnf_file
fi
sed -i "s/\(.*bind-address.*\)/#\1/" $mysql_cnf_file
sed -i "s/\(.*max_connections.*\)/#\1/" $mysql_cnf_file
echo "bind-address                = 0.0.0.0" >> $mysql_cnf_file
echo "max_connections                = 1024" >> $mysql_cnf_file

service mysql restart
service mariadb restart

#echo "Mysql secure installation started" >> $LOGFILE
#echo -e "\ny\ny\n$mariadb_passwd\n$mariadb_passwd\ny\ny\ny\ny" |/usr/bin/mysql_secure_installation >> $LOGFILE
#echo -e "\ny\n$mariadb_passwd\n$mariadb_passwd\ny\nn\ny\ny" |/usr/bin/mysql_secure_installation >> $LOGFILE
#check_exit_status "/usr/bin/mysql_secure_installation"  >> $LOGFILE 
mysql -u root -p$mariadb_passwd -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$mariadb_passwd' WITH GRANT OPTION;" >> $LOGFILE
check_exit_status "Enabling mysql remote access"  >> $LOGFILE
mysql -u root -p$mariadb_passwd -e "DROP DATABASE $perf_db;" >> $LOGFILE
mysql -u root -p$mariadb_passwd -e "CREATE DATABASE $perf_db;" >> $LOGFILE
mysql -u root -p$mariadb_passwd -e "SET GLOBAL max_connections = 5000;" >> $LOGFILE
mysql -u root -p$mariadb_passwd -e "FLUSH PRIVILEGES;" >> $LOGFILE
check_exit_status "Created database for performance"  >> $LOGFILE
service mysql restart
service mariadb restart
echo "done"
