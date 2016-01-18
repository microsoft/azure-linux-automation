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
raidName="/dev/md1"
mountdir="/dataIOtest"
code_path="/home/$username/code"
LOGFILE="${code_path}/iotest.log.txt"
echo "IO test setup started.." >> $LOGFILE
list=(`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$" `)
count=0
while [ "x${list[count]}" != "x" ]
do
   echo ${list[$count]}  >> $LOGFILE 
   (echo n; echo p; echo 2; echo; echo; echo t; echo fd; echo w;) | fdisk ${list[$count]}  >> $LOGFILE
   count=$(( $count + 1 ))   
done

lsblk  >> $LOGFILE

echo "--- Raid $raidName creation started ---" >> $LOGFILE
(echo y)| mdadm --create $raidName --level 0 --raid-devices ${#list[@]} ${list[@]} >> $LOGFILE
if [ $? -ne 0 ]; then
	echo "$raidName Raid creation: Failed"  >> $LOGFILE
    exit 80
fi
echo "$raidName Raid creation: Success"  >> $LOGFILE

time mkfs.ext4 $raidName >> $LOGFILE
if [ $? -ne 0 ]; then
	echo "$raidName Raid format: Failed"   >> $LOGFILE
    exit 80
fi
echo "$raidName Raid format: Success"  >> $LOGFILE
mkdir $mountdir
uuid=`blkid $raidName| sed "s/.*UUID=\"//"| sed "s/\".*\"//"`
echo $uuid
echo "UUID=$uuid $mountdir ext4 defaults 0 2" >> /etc/fstab
mount -o nobarrier $raidName $mountdir
if [ $? -ne 0 ]; then
	echo "$raidName Raid mount: Failed"  >> $LOGFILE
    exit 80	
fi
echo "$raidName Raid mount: Success on $mountdir"  >> $LOGFILE
df -hT >> $LOGFILE
cp $code_path/sysbench-full-io-test.sh $mountdir
bash $code_path/keep_cmds_in_startup.sh "cd $mountdir ; bash $mountdir/sysbench-full-io-test.sh $username &" 
