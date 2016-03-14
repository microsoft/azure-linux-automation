#!/bin/bash
#
# This script will execute either "Extend logical volume" or "Shrink logical volume" based on given test param.
# Run the script : ./lvm_extend_shrink_test.sh <username> <testparam>
# Ex: ./lvm_extend_shrink_test.sh test Extend
# ./lvm_extend_shrink_test.sh test Shrink
#
# Author: Ranjith Muthineni
# Email	: v-ranmut@microsoft.com
#
#####################################################

if [[ $# == 2 ]]
then
	username=$1
	testparam=$2
else
	echo "Usage: bash $0 <username>"
	exit -1
fi

. /home/$username/azuremodules.sh

#Function for LVM functional setup.
lvm_extend_setup () {
	#Create a partition of LVM type (Hex 8e) on the new disk
	(echo n;echo p;echo 1;echo;echo;echo t;echo 8e;echo p;echo w)|fdisk -c -u $DATA_DISK
	fdisk -l $DATA_DISK | grep $DATA_PARTITION
	check_exit_status "Create a partition of LVM type on data disk" exit

	#Create a physical volume with the new partition
	pvcreate $DATA_PARTITION
	check_exit_status "Physical volume $DATA_PARTITION create" exit
	pvs
	
	#Extend the volume group with the new PV
	vgs $VG_NAME 
	vgextend $VG_NAME $DATA_PARTITION
	check_exit_status "Extend the volume group" exit
	vgs $VG_NAME 
	
	#Extend the root LV and resize the file system
	lvs $LV_FULLNAME
	lvextend -l +100%FREE $LV_FULLNAME --resize
	check_exit_status "Extend the root LV" exit
	resize2fs $LV_FULLNAME
	lvs $LV_FULLNAME
}

#Function for LVM functional setup.
lvm_shrink_setup () {
	#Shrink the LV to reduce the size of the data disk
	set $(pvs --noheadings -o pv_pe_count,pv_pe_alloc_count $DATA_PARTITION)
	Total_PE=$1
	Allocated_PE=$2
	echo "Total_PE:$Total_PE" "Allocated_PE:$Allocated_PE"

	lvdisplay $LV_FULLNAME
	lvreduce -l -$Total_PE -f $LV_FULLNAME
	check_exit_status "Shrink the root LV" exit
	resize2fs $LV_FULLNAME
	lvdisplay $LV_FULLNAME

	#Check whether the PV of the data disk partition is Free
	#If it’s not all free, move the data of the partition
	pvs -o+pv_used
	pvmove $DATA_PARTITION

	#Remove the PV from VG
	vgs $VG_NAME
	vgreduce $VG_NAME $DATA_PARTITION
	check_exit_status "Remove the PV from VG" exit
	vgs $VG_NAME

	#Remove physical volume
	pvremove $DATA_PARTITION
	check_exit_status "Physical volume $DATA_PARTITION remove" exit

	#Remove attached disk partition
	(echo d;echo p;echo w)|fdisk $DATA_DISK
	! (fdisk -l $DATA_DISK | grep $DATA_PARTITION)
	check_exit_status "Remove attached disk partition" exit
}
###########################################################################
#Main script.
###########################################################################
echo "We are running $testparam LVM Functional test."

#Get the required variables for test
sleep 60 
DATA_DISK=`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$"`
check_exit_status "Disk is attached" exit
DATA_PARTITION=${DATA_DISK}1
echo "DATA_DISK:$DATA_DISK" "DATA_PARTITION:$DATA_PARTITION"
set $(lvs --noheadings -o lv_name,vg_name)
LV_NAME=$1
VG_NAME=$2
LV_FULLNAME=/dev/$VG_NAME/$LV_NAME
echo "LV_NAME:$LV_NAME" "VG_NAME:$VG_NAME" "LV_FULLNAME:$LV_FULLNAME"
echo "We are using $DATA_DISK data disk and $LV_FULLNAME Logical volume"

#Collect dmesg logs
echo "Collect inital system logs"
dmesg > dmesg-beforetest.txt

if [ "$testparam" == "Extend" ]; then
	#Before stating the test, make sure iozone test is running
	pgrep iozone
	check_exit_status "Make sure iozone test is running" exit
	
	#Running LVM extend setup.
	lvm_extend_setup
elif [ "$testparam" == "Shrink" ]; then
	#Running LVM extend setup.
	lvm_extend_setup
	
	#Start IOZone to read/write data on the root LV
	iozone -a -z -g 256m -k 16 -Vazure >> iozone_output.txt &
	sleep 30
	pgrep iozone
	check_exit_status "IOZone test is running" exit
	
	#Running LVM shrink setup.
	lvm_shrink_setup
	
	#Now Deattach the data disk.
	echo "Now Deattach the data disk using powershell"
	while [ -b $DATA_DISK ]
	do
		echo "data disk is still exist, please wait"
		sleep 10
	done
	echo "data disk is removed successfully" 	
else
	echo "Please pass valid test param for test"
fi

#Check IOZone finished successfully and there’s no error in system logs
#Make sure IOZone test is still running after LVM test
pgrep iozone
check_exit_status "Make sure IOZone test is still running after LVM test" exit

#Wait till IOZone finished successfully
while [ `pgrep iozone` ]
do
	echo "iozone test is still running, please wait"
	sleep 60
done

grep "iozone test complete" iozone_output.txt
check_exit_status "IOZone test finished" exit

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
