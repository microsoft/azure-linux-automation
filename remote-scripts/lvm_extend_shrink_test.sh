#!/bin/bash
#
# This script will execute either "Extend logical volume" or "Shrink logical volume" based on given test param.
# Run the script : ./lvm_extend_shrink_test.sh <username> <testparam>
# Ex: ./lvm_extend_shrink_test.sh test rootdisk/datadisk Extend
# ./lvm_extend_shrink_test.sh test rootdisk/datadisk Shrink
#
# Author: Ranjith Muthineni
# Email	: v-ranmut@microsoft.com
#
#####################################################

if [[ $# == 3 ]]
then
	username=$1
	diskparam=$2
	testparam=$3
else
	echo "Usage: bash $0 <username>"
	exit -1
fi

. /home/$username/azuremodules.sh

#Function for LVM setup.
lvm_setup () {
	echo "--- LVM $LV_FULLNAME creation started ---"

	#Create a partition of LVM type (Hex 8e) on the new disk
	(echo n;echo p;echo 1;echo;echo;echo t;echo 8e;echo p;echo w)|fdisk -c -u $LVM_DISK
	fdisk -l $LVM_DISK | grep $LVM_PARTITION
	check_exit_status "Create a partition of LVM type on $LVM_DISK data disk" exit

	yes | pvcreate $LVM_PARTITION
	check_exit_status "Physical volume $LVM_PARTITION create" exit
	pvs

	vgcreate $VG_NAME $LVM_PARTITION
	check_exit_status "Volume group $VG_NAME create" exit
	vgs $VG_NAME

	lvcreate -l 100%FREE $VG_NAME -n $LV_NAME
	check_exit_status "Logical Volume $LV_FULLNAME create" exit
	lvs $LV_FULLNAME

	if grep -q "SUSE Linux Enterprise Server 11" /etc/*-release
	then
		echo "Formatting $LV_FULLNAME with ext3 FS"
		time mkfs.ext3 $LV_FULLNAME
	else
		echo "Formatting $LV_FULLNAME with ext4 FS"
		time mkfs.ext4 $LV_FULLNAME
	fi
	check_exit_status "Logical Volume $LV_FULLNAME format" exit

	mount -o barrier=0 $LV_FULLNAME $mountdir
	check_exit_status "Logical Volume $LV_FULLNAME mount on $mountdir" exit

	uuid=`blkid $LV_FULLNAME| sed "s/.*UUID=\"//"| sed "s/\".*\"//"`
	echo $uuid
	echo "UUID=$uuid $mountdir ext4 defaults,barrier=0 0 2" >> /etc/fstab
}

#Function for LVM Extend setup.
lvm_extend_setup () {
	#Create a partition of LVM type (Hex 8e) on the new disk
	(echo n;echo p;echo 1;echo;echo;echo t;echo 8e;echo p;echo w)|fdisk -c -u $DATA_DISK
	fdisk -l $DATA_DISK | grep $DATA_PARTITION
	check_exit_status "Create a partition of LVM type on $DATA_DISK data disk" exit

	#Create a physical volume with the new partition
	pvcreate $DATA_PARTITION
	check_exit_status "Physical volume $DATA_PARTITION create" exit
	pvs

	#Extend the volume group with the new PV
	vgs $VG_NAME
	vgextend $VG_NAME $DATA_PARTITION
	check_exit_status "Extend the volume group $VG_NAME with $DATA_PARTITION PV" exit
	vgs $VG_NAME

	#Extend the root LV and resize the file system
	lvs $LV_FULLNAME
	lvextend -l +100%FREE $LV_FULLNAME --resize
	check_exit_status "Extend the root LV $LV_FULLNAME" exit
	resize2fs $LV_FULLNAME
	lvs $LV_FULLNAME
}

#Function for LVM Shrink setup.
lvm_shrink_setup () {
	#Shrink the LV to reduce the size of the data disk
	set $(pvs --noheadings -o pv_pe_count,pv_pe_alloc_count $DATA_PARTITION)
	Total_PE=$1
	Allocated_PE=$2
	echo "Total_PE:$Total_PE" "Allocated_PE:$Allocated_PE"

	lvdisplay $LV_FULLNAME
	lvreduce -l -$Total_PE -f $LV_FULLNAME
	check_exit_status "Shrink the root LV $LV_FULLNAME" exit
	resize2fs $LV_FULLNAME
	lvdisplay $LV_FULLNAME

	#Check whether the PV of the data disk partition is Free
	#If it’s not all free, move the data of the partition
	pvs -o+pv_used
	pvmove $DATA_PARTITION

	#Remove the PV from VG
	vgs $VG_NAME
	vgreduce $VG_NAME $DATA_PARTITION
	check_exit_status "Remove the $DATA_PARTITION PV from $VG_NAME VG" exit
	vgs $VG_NAME

	#Remove physical volume
	pvremove $DATA_PARTITION
	check_exit_status "Physical volume $DATA_PARTITION remove" exit

	#Remove attached disk partition
	(echo d;echo p;echo w)|fdisk $DATA_DISK
	! (fdisk -l $DATA_DISK | grep $DATA_PARTITION)
	check_exit_status "Remove attached disk partition $DATA_PARTITION" exit
}

#Function for trigger iozone test
iozone_test () {
	echo "Running iozone test on $diskparam"
	if [ "$diskparam" == "rootdisk" ]; then
		iozone -a -z -g 10g -k 16 -Vazure >> /home/$username/iozone_output.txt &
	else
		(cd $mountdir && iozone -a -z -g 10g -k 16 -Vazure >> /home/$username/iozone_output.txt &)
	fi
	sleep 30
	pgrep iozone
	check_exit_status "Make sure iozone test is running" exit
}

###########################################################################
#Main script.
###########################################################################
echo "We are running $testparam LVM Functional test on $diskparam."

#Collect dmesg logs
echo "Collect inital system logs"
dmesg > dmesg-beforetest.txt

#Get the required variables for test
sleep 60
if [ "$diskparam" == "rootdisk" ]; then
	set $(lvs --noheadings -o lv_name,vg_name)
	LV_NAME=$1
	VG_NAME=$2
	LV_FULLNAME=/dev/$VG_NAME/$LV_NAME
	echo "LV_NAME:$LV_NAME" "VG_NAME:$VG_NAME" "LV_FULLNAME:$LV_FULLNAME"
	echo "We are using $DATA_DISK data disk and $LV_FULLNAME Logical volume"
elif [ "$diskparam" == "datadisk" ]; then
	LVM_DISK=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$"`
	check_exit_status "Datd disk is attached for LVM setup" exit
	LVM_PARTITION=${LVM_DISK}1
	echo "LVM_DISK:$LVM_DISK" "LVM_PARTITION:$LVM_PARTITION"
	LV_NAME=lv1
	VG_NAME=vg1
	LV_FULLNAME=/dev/$VG_NAME/$LV_NAME
	mountdir=/dataLVM
	[ ! -d $mountdir ] && mkdir $mountdir
	echo "LV_NAME:$LV_NAME" "VG_NAME:$VG_NAME" "LV_FULLNAME:$LV_FULLNAME"
	echo "We are using $LVM_DISK data disk for create $LV_FULLNAME Logical volume"
	lvm_setup
else
	echo "Please pass valid test param for diskparam"
fi

#Attach data disk for LVM Extend
i=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' | wc -l`
j=$i
echo "Now Attach data disk for LVM test using powershell"
while [ $i -eq $j ]
do
	echo "data disk is not exist, please wait"
	j=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' | wc -l`
	sleep 30
done
echo "Data disk is attached successfully for LVM functional test"
DATA_DISK=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$"| tail -1`
DATA_PARTITION=${DATA_DISK}1
echo "DATA_DISK:$DATA_DISK" "DATA_PARTITION:$DATA_PARTITION"

if [ "$testparam" == "Extend" ]; then
	#Trigger iozone test on $diskparam
	iozone_test

	#Running LVM extend setup.
	lvm_extend_setup
elif [ "$testparam" == "Shrink" ]; then
	#Running LVM extend setup.
	lvm_extend_setup

	#Trigger iozone test on $diskparam
	iozone_test

	#Running LVM shrink setup.
	lvm_shrink_setup

	#Now Deattach the data disk.
	i=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' | wc -l`
	j=$i
	echo "Now Deattach the data disk using powershell"
	while [ $i -eq $j ]
	do
		echo "data disk $DATA_DISK is still exist, please wait"
		j=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' | wc -l`
		sleep 30
	done
	echo "data disk $DATA_DISK is removed successfully"
else
	echo "Please pass valid test param for test"
fi

#Check IOZone finished successfully and there’s no error in system logs
#Make sure IOZone test is still running after LVM test
pgrep iozone
check_exit_status "Make sure IOZone test is still running after LVM test" exit
count=0
#Wait till IOZone finished successfully
while [ `pgrep iozone` ]
do
	echo "iozone test is still running, please wait"
	count=$((count+1))
	if [ $count -gt 30 ]; then
		echo -e "\niozone test complete.\n" >> /home/$username/iozone_output.txt
		echo "Loop count exceeded maximum limit"
		killall iozone
		break
	fi
	echo $count
	sleep 60
done

grep "iozone test complete" /home/$username/iozone_output.txt
check_exit_status "IOZone test status" exit

#Checking errors in system logs
dmesg > dmesg-aftertest.txt
diff dmesg-beforetest.txt dmesg-aftertest.txt | egrep 'fail|error|trace' | egrep -v 'floppy|fd0' > systemerrorlogs.txt
if [ `cat systemerrorlogs.txt | wc -l` -gt 0 ]; then
	echo "we got error logs in system logs"
	cat systemerrorlogs.txt
else
	echo "no errors in system logs"
fi

echo "LVM functionlal test completed"

echo "Compressing log files.. "
cd /home/$username; tar -cvf logs.tar *.txt

exit 0
