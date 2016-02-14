#!/bin/bash
#
# This script does the following:
# 1. Prepares the RAID with all the data disks attached 
# 2. Places an entry for the created RAID in /etc/fstab.
# 3. Keep the sysbench test script in the startup for IO performance test.
#
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#
#####
username=$1
test_type=$2

mountdir="/dataIOtest"
code_path="/home/$username/code"
LOGFILE="${code_path}/iotest.log.txt"
[ -d $mountdir ] && umount $mountdir && rm -rf $mountdir
mkdir $mountdir  
echo "IO test setup started.." > $LOGFILE
list=(`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$" `)

lsblk  >> $LOGFILE

if [ "$test_type" == "LVM" ]; then
	deviceName="/dev/vg1/lv1"
	echo "--- LVM $deviceName creation started ---" >> $LOGFILE

	yes | pvcreate ${list[@]} >> $LOGFILE
	if [ $? -ne 0 ]; then
		echo "pvcreate: Failed"  >> $LOGFILE
		exit 80
	fi
	echo "pvcreate: Success"  >> $LOGFILE

	vgcreate vg1 ${list[@]} >> $LOGFILE
	if [ $? -ne 0 ]; then
		echo "vgcreate : Failed"  >> $LOGFILE
		exit 80
	fi
	echo "vgcreate : Success"  >> $LOGFILE

	lvcreate -l 100%FREE -i 32 -I 64 vg1 -n lv1
	if [ $? -ne 0 ]; then
		echo "lvcreate: Failed"  >> $LOGFILE
		exit 80
	fi
	echo "lvcreate : Success"  >> $LOGFILE

	time mkfs.ext4 $deviceName >> $LOGFILE
	
	mount -o barrier=0 $deviceName $mountdir
	if [ $? -ne 0 ]; then
		echo "$deviceName LVM mount: Failed"  >> $LOGFILE
		exit 80	
	fi
	echo "$deviceName LVM mount: Success on $mountdir"  >> $LOGFILE
	uuid=`blkid $deviceName| sed "s/.*UUID=\"//"| sed "s/\".*\"//"`
	echo $uuid
	echo "UUID=$uuid $mountdir ext4 defaults,barrier=0 0 2" >> /etc/fstab

elif [ "$test_type" == "RAID" ]; then
	count=0
	while [ "x${list[count]}" != "x" ]
	do
	   echo ${list[$count]}  >> $LOGFILE 
	   (echo n; echo p; echo 2; echo; echo; echo t; echo fd; echo w;) | fdisk ${list[$count]}  >> $LOGFILE
	   count=$(( $count + 1 ))   
	done
	
	deviceName="/dev/md1"
	echo "--- Raid $deviceName creation started ---" >> $LOGFILE
	(echo y)| mdadm --create $deviceName --level 0 --raid-devices ${#list[@]} ${list[@]} >> $LOGFILE
	if [ $? -ne 0 ]; then
		echo "$deviceName Raid creation: Failed"  >> $LOGFILE
		exit 80
	fi
	echo "$deviceName Raid creation: Success"  >> $LOGFILE

	time mkfs.ext4 $deviceName >> $LOGFILE
	if [ $? -ne 0 ]; then
		echo "$deviceName Raid format: Failed"   >> $LOGFILE
		exit 80
	fi
	echo "$deviceName Raid format: Success"  >> $LOGFILE
	
	mount -o nobarrier $deviceName $mountdir
	if [ $? -ne 0 ]; then
		echo "$deviceName Raid mount: Failed"  >> $LOGFILE
		exit 80	
	fi
	echo "$deviceName Raid mount: Success on $mountdir"  >> $LOGFILE
	uuid=`blkid $deviceName| sed "s/.*UUID=\"//"| sed "s/\".*\"//"`
	echo $uuid
	echo "UUID=$uuid $mountdir ext4 defaults,barrier=0 0 2" >> /etc/fstab
else
	echo "Unknown DiskType $test_type: Aborted"  >> $LOGFILE
fi

df -hT >> $LOGFILE
cp $code_path/sysbench-full-io-test.sh $mountdir
bash $code_path/keep_cmds_in_startup.sh "cd $mountdir ; bash $mountdir/sysbench-full-io-test.sh $username &" 
