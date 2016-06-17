#!/bin/bash

#######################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
#######################################################################

#######################################################################
#
# performance_middleware_fio.sh
#
# Description:
#    Install fio so the fio benchmark can
#    be run.  This script needs to be run on single VM.
#
#    steps:
#
#     1. Install a fio
#     2. Start fio benchmark test on given disk
#######################################################################


#
# Constants/Globals
#
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test

CONSTANTS_FILE="constants.sh"
SUMMARY_LOG=~/summary.log

#MONGODB_VERSION="2.4.0"
#MONGODB_ARCHIVE="mongodb-linux-x86_64-${MONGODB_VERSION}.tgz"
#MONGODB_URL="http://fastdl.mongodb.org/linux/${MONGODB_ARCHIVE}"

#######################################################################
#
# LogMsg()
#
#######################################################################
LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> ~/Fio.log
}


#######################################################################
#
# UpdateTestState()
#
#######################################################################
UpdateTestState()
{
    echo "${1}" > ~/state.txt
}


#######################################################################
#
# UpdateSummary()
#
#######################################################################
UpdateSummary()
{
    echo "${1}" >> ~/summary.log
}


#######################################################################
#
# TimeToSeconds()
#
#######################################################################
TimeToSeconds()
{
    read -r h m s <<< $(echo $1 | tr ':' ' ')
    #echo $(((h*60*60)+(m*60)+s))
    echo `echo "${h}*60*60+${m}*60+${s}" | bc`
}


#######################################################################
#
# LinuxRelease()
#
#######################################################################
LinuxRelease()
{
    DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`

    case $DISTRO in
        *buntu*)
            echo "UBUNTU";;
        Fedora*)
            echo "FEDORA";;
        CentOS*)
            echo "CENTOS";;
        *SUSE*)
            echo "SLES";;
        Red*Hat*)
            echo "RHEL";;
        Debian*)
            echo "DEBIAN";;
    esac
}

set -u
set -x

RunFIO()
{
	FILEIO="--size=16G --direct=1 --ioengine=libaio --filename=fiodata --overwrite=1  "

	####################################
	#All run config set here
	#

	#Log Config
	
	mkdir -p  $HOMEDIR/FIOLog/jsonLog
	mkdir -p  $HOMEDIR/FIOLog/iostatLog
	mkdir -p  $HOMEDIR/FIOLog/blktraceLog

	#LOGDIR="${HOMEDIR}/FIOLog"
	JSONFILELOG="${LOGDIR}/jsonLog"
	IOSTATLOGDIR="${LOGDIR}/iostatLog"
	BLKTRACELOGDIR="${LOGDIR}/blktraceLog"
	LOGFILE="${LOGDIR}/fio-test.log.txt"	

	#redirect blktrace files directory
	Resource_mount=$(mount -l | grep /sdb1 | awk '{print$3}')
	blk_base="${Resource_mount}/blk-$(date +"%m%d%Y-%H%M%S")"
	mkdir $blk_base
	#
	#
	#Test config
	#
	#

	#All possible values for file-test-mode are randread randwrite read write
	modes='read write'
	iteration=0
	startIOdepth=${startIOdepth}
	startIOsize=${startIOsize}
	numjobs=1

	#Max run config
	ioruntime=${ioruntime}
	maxIOdepth=${maxIOdepth}
	maxIOsize=${maxIOsize}

	####################################
	echo "Test log created at: ${LOGFILE}"
	LogMsg "===================================== Starting Run $(date +"%x %r %Z") ================================"
	echo "===================================== Starting Run $(date +"%x %r %Z") ================================" >> $LOGFILE

	chmod 666 $LOGFILE
	LogMsg "Preparing Files: $FILEIO"
	echo "Preparing Files: $FILEIO" >> $LOGFILE
	# Remove any old files from prior runs (to be safe), then prepare a set of new files.
	rm fiodata
	LogMsg "--- Kernel Version Information ---"
	echo "--- Kernel Version Information ---" >> $LOGFILE
	uname -a >> $LOGFILE
	cat /proc/version >> $LOGFILE
	cat /etc/*-release >> $LOGFILE
	echo "--- PCI Bus Information ---" >> $LOGFILE
	lspci >> $LOGFILE
	echo "--- Drive Mounting Information ---" >> $LOGFILE
	mount >> $LOGFILE
	echo "--- Disk Usage Before Generating New Files ---" >> $LOGFILE
	df -h >> $LOGFILE
	fio --cpuclock-test >> $LOGFILE
	fio $FILEIO --readwrite=read --bs=1M --runtime=1 --iodepth=128 --numjobs=8 --name=prepare >> $LOGFILE
	echo "--- Disk Usage After Generating New Files ---" >> $LOGFILE
	df -h >> $LOGFILE
	echo "=== End Preparation  $(date +"%x %r %Z") ===" >> $LOGFILE

	####################################
	#Trigger run from here
	for testmode in $modes; do
		iosize=$startIOsize
		while [ $iosize -le $maxIOsize ]
		do
			IOdepth=$startIOdepth			
			while [ $IOdepth -le $maxIOdepth ]
			do
				if [ $IOdepth -ge 8 ]
				then
					numjobs=8
				else
					numjobs=$IOdepth
				fi
				iostatfilename="${IOSTATLOGDIR}/iostat-fio-${testmode}-${iosize}K-${IOdepth}td.txt"
				nohup iostat -x 5 -t -y > $iostatfilename &
							
				#LogMsg "-- iteration ${iteration} ----------------------------- ${testmode} test, ${iosize}K bs, ${IOdepth} threads, ${numjobs} jobs, 5 minutes ------------------ $(date +"%x %r %Z") ---"
				echo "-- iteration ${iteration} ----------------------------- ${testmode} test, ${iosize}K bs, ${IOdepth} threads, ${numjobs} jobs, 5 minutes ------------------ $(date +"%x %r %Z") ---" >> $LOGFILE
				jsonfilename="${JSONFILELOG}/fio-result-${testmode}-${iosize}K-${IOdepth}td.json"
				fio $FILEIO --readwrite=$testmode --bs=${iosize}K --runtime=$ioruntime --iodepth=$IOdepth --numjobs=$numjobs --output-format=json --output=$jsonfilename --name="iteration"${iteration} >> $LOGFILE
				#fio $FILEIO --readwrite=$testmode --bs=${iosize}K --runtime=$ioruntime --iodepth=$IOdepth --numjobs=$numjobs --name="iteration"${iteration} --group_reporting >> $LOGFILE
				iostatPID=`ps -ef | awk '/iostat/ && !/awk/ { print $2 }'`
				kill -9 $iostatPID
				IOdepth=$(( IOdepth*2 ))		
				iteration=$(( iteration+1 ))
			done
		iosize=$(( iosize*2 ))
		done
	done
	####################################
	#LogMsg "===================================== Completed Run $(date +"%x %r %Z") script generated 2/9/2015 4:24:44 PM ================================"
	echo "===================================== Completed Run $(date +"%x %r %Z") script generated 2/9/2015 4:24:44 PM ================================" >> $LOGFILE
	rm fiodata

	compressedFileName="${HOMEDIR}/FIOTest-$(date +"%m%d%Y-%H%M%S").tar.gz"
	LogMsg "INFO: Please wait...Compressing all results to ${compressedFileName}..."
	tar -cvzf $compressedFileName $LOGDIR/

	echo "Test logs are located at ${LOGDIR}"
}

ConfigCentOS7()
{			
	fioCentOS7pkg="fio-2.1.10-1.el7.rf.x86_64.rpm"
	LogMsg "INFO: CentOS7: installing required packages"
	yum install -y wget sysstat mdadm blktrace
	mount -t debugfs none /sys/kernel/debug
	
	installed=`which fio`
	if [ ! $installed ]; then
        LogMsg "INFO: Installing fio"

		fiolPkg=$(ls | grep ${fioCentOS7pkg})
		if [ -z "$fiolPkg" ]; then
			wget "http://pkgs.repoforge.org/fio/${fioCentOS7pkg}"
		fi
		yum install -y ${fioCentOS7pkg}
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to install fio"
            exit 1
        fi
    fi	
}

ConfigCentOS6()
{			
	fioCentOS6pkg="fio-2.1.10-1.el6.rf.x86_64.rpm"
	LogMsg "INFO: CentOS6: installing required packages"
	yum install -y wget sysstat mdadm blktrace
	mount -t debugfs none /sys/kernel/debug
	
	installed=`which fio`
	if [ ! $installed ]; then
        LogMsg "INFO: Installing fio"

		fiolPkg=$(ls | grep ${fioCentOS6pkg})
		if [ -z "$fiolPkg" ]; then			
			wget "http://pkgs.repoforge.org/fio/${fioCentOS6pkg}"
		fi
		yum install -y libibverbs.x86_64
		yum install -y ${fioCentOS6pkg}
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to install fio"
            exit 1
        fi
    fi	
}

ConfigUbuntu()
{
	LogMsg "INFO: Ubuntu installing required packages"
	
	
	apt-get install -y wget tar sysstat blktrace
	mount -t debugfs none /sys/kernel/debug
	
	installed=`which fio`
	if [ ! $installed ]; then
        LogMsg "INFO: Installing fio"

		apt-get install -y fio ;
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to install fio"
            exit 1
        fi
    fi
}

ConfigSLES()
{
	fioCentOS6pkg="fio-2.1.2-2.1.3.x86_64.rpm"
	LogMsg "INFO: SLES: installing required packages"
	zypper --non-interactive install wget sysstat mdadm blktrace
	mount -t debugfs none /sys/kernel/debug
	
	installed=`which fio`
	if [ ! $installed ]; then
        LogMsg "INFO: Installing fio"

		fiolPkg=$(ls | grep ${fioCentOS6pkg})
		if [ -z "$fiolPkg" ]; then			
			wget "ftp://195.220.108.108/linux/opensuse/distribution/13.1/repo/oss/suse/x86_64/${fioCentOS6pkg}"
		fi		
		(echo i;) | zypper --non-interactive install ${fioCentOS6pkg}
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to install fio"
            exit 1
        fi
    fi	
}

CreateRAID0()
{	
	disks=$(ls -l /dev | grep sd[c-z]$ | awk '{print $10}')
	#disks=(`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$" `)
	
	LogMsg "INFO: Check and remove RAID first"
	mdvol=$(cat /proc/mdstat | grep "active raid" | awk {'print $1'})
	if [ -n "$mdvol" ]; then
		echo "/dev/${mdvol} already exist...removing first"
		umount /dev/${mdvol}
		mdadm --stop /dev/${mdvol}
		mdadm --remove /dev/${mdvol}
		mdadm --zero-superblock /dev/sd[c-z][1-5]
	fi
	
	LogMsg "INFO: Creating Partition"
	count=0
	for disk in ${disks}
	do		
		echo "formatting disk /dev/${disk}"
		(echo d; echo n; echo p; echo 1; echo; echo; echo t; echo fd; echo w;) | fdisk /dev/${disk}
		count=$(( $count + 1 )) 
	done
	
	LogMsg "INFO: Creating RAID"
	mdadm --create ${mdVolume} --level 0 --raid-devices ${count} /dev/sd[c-z][1-5]
	time mkfs -y $1 -F ${mdVolume}
	mkdir ${mountDir}
	mount -o nobarrier ${mdVolume} ${mountDir}
	if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to create raid"            
            exit 1
        fi
	
	#LogMsg "INFO: adding fstab entry"
	#echo "${mdVolume}	${mountDir}	ext4	defaults	1 1" >> /etc/fstab
}

CreateLVM()
{	
	disks=$(ls -l /dev | grep sd[c-z]$ | awk '{print $10}')
	#disks=(`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$" `)
	
	#LogMsg "INFO: Check and remove LVM first"
	vgExist=$(vgdisplay)
	if [ -n "$vgExist" ]; then
		umount ${mountDir}
		lvremove -A n -f /dev/${vggroup}/lv1
		vgremove ${vggroup} -f
	fi
	
	LogMsg "INFO: Creating Partition"
	count=0
	for disk in ${disks}
	do		
		echo "formatting disk /dev/${disk}"
		(echo d; echo n; echo p; echo 1; echo; echo; echo t; echo fd; echo w;) | fdisk /dev/${disk}
		count=$(( $count + 1 )) 
	done
	
	LogMsg "INFO: Creating LVM with all data disks"
	pvcreate /dev/sd[c-z][1-5]
	vgcreate ${vggroup} /dev/sd[c-z][1-5]
	lvcreate -l 100%FREE -i 12 -I 64 ${vggroup} -n lv1
	time mkfs -t $1 -F /dev/${vggroup}/lv1
	mkdir ${mountDir}
	mount -o nobarrier /dev/${vggroup}/lv1 ${mountDir}
	if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to create LVM "            
            exit 1
        fi
	
	#LogMsg "INFO: adding fstab entry"
	#echo "${mdVolume}	${mountDir}	ext4	defaults	1 1" >> /etc/fstab
}

############################################################
#	Main body
############################################################

#cd ~

UpdateTestState $ICA_TESTRUNNING
LogMsg "Updated test case state to running"

rm -f ~/summary.log
touch ~/summary.log

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    echo "${errMsg}" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

HOMEDIR=$HOME
mv $HOMEDIR/FIOLog/ $HOMEDIR/FIOLog-$(date +"%m%d%Y-%H%M%S")/
mkdir -p $HOMEDIR/FIOLog
LOGDIR="${HOMEDIR}/FIOLog"
#mdVolume="/dev/md1"
#vggroup="vg1"
mountDir="/sdc1mnt/fio"
testdisk=${testdisk}
echo "Disk for FIO benchmark test $testdisk" && (echo n; echo p; echo 1; echo; echo; echo t; echo 83; echo w;) | fdisk $testdisk && time mkfs.ext4 ${testdisk}1 && echo "${testdisk}1 disk format: Success" && mkdir -p $mountDir && mount -o nobarrier ${testdisk}1 $mountDir && echo "${testdisk}1 disk mount: Success on $mountDir"
if [ $? -ne 0 ]; then
    LogMsg "Error: Disk for FIO benchmark test $testdisk: FAILED"
    UpdateTestState $ICA_TESTFAILED
    exit 1
fi
LogMsg "Disk for FIO benchmark test $testdisk is mounted on $mountDir: Success"

cd ${HOMEDIR}

DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`

case $DISTRO in
	Ubuntu*)
		echo "UBUNTU"
		ConfigUbuntu
		;;
	Fedora*)
		echo "FEDORA";;
	*release*7.*)
		echo "CENTOS 7.*"
		ConfigCentOS7
		;;
	*release*6.*)
		echo "CENTOS 6.*"
		ConfigCentOS6
		;;
	*SUSE*)
		echo "SLES"
		ConfigSLES
		;;
	Red*Hat*)
		echo "RHEL";;
	Debian*)
		echo "DEBIAN";;
esac
#Creating RAID before triggering test
#CreateRAID0 ext4
#CreateLVM ext4

#Run test from here
LogMsg "*********INFO: Starting test execution*********"
cd ${mountDir}
mkdir sampleDIR
RunFIO
LogMsg "*********INFO: Script execution reach END. Completed !!!*********"