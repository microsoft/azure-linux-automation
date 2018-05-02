#!/bin/bash
##############################################################
# perf_diskspd.sh
# Author : Maruthi Sivakanth Rebba <v-sirebb@microsoft.com>
# 
#Description:
#	Download and run diskspd disk io performance tests.
##############################################################

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test

LogMsg()
{
    echo "[$(date +"%x %r %Z")] ${1}"
	echo "[$(date +"%x %r %Z")] ${1}" >> "${HOMEDIR}/runlog.txt"
}

UpdateTestState()
{
    echo "${1}" > $HOMEDIR/state.txt
}

InstallDependencies() {
	LogMsg "INFO: Dependency installation started..."
	DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`

	if [[ $DISTRO =~ "Ubuntu" ]] || [[ $DISTRO =~ "Debian" ]];
	then
		LogMsg "INFO: Detected UBUNTU/Debian"
		until dpkg --force-all --configure -a; sleep 10; do echo 'Trying again...'; done
		apt-get update
		apt-get install -y pciutils gawk mdadm
		apt-get install -y wget sysstat blktrace bc gcc make libaio-dev g++ git 
		if [ $? -ne 0 ]; then
			LogMsg "Error: Unable to install fio"
			exit 1
		fi
		mount -t debugfs none /sys/kernel/debug
						
	elif [[ $DISTRO =~ "Red Hat Enterprise Linux Server release 6" ]];
	then
		LogMsg "INFO: Detected RHEL 6.x"
		LogMsg "INFO: installing required packages"
		rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
		yum -y --nogpgcheck install wget sysstat mdadm blktrace libaio gcc make libaio-dev g++ git 
		mount -t debugfs none /sys/kernel/debug

	elif [[ $DISTRO =~ "Red Hat Enterprise Linux Server release 7" ]];
	then
		LogMsg "INFO: Detected RHEL 7.x"
		LogMsg "INFO: installing required packages"
		rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		yum -y --nogpgcheck install wget sysstat mdadm blktrace libaio gcc make libaio-dev g++ git 
		mount -t debugfs none /sys/kernel/debug
			
	elif [[ $DISTRO =~ "CentOS Linux release 6" ]] || [[ $DISTRO =~ "CentOS release 6" ]];
	then
		LogMsg "INFO: Detected CentOS 6.x"
		LogMsg "INFO: installing required packages"
		rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
		yum -y --nogpgcheck install wget sysstat mdadm blktrace libaio gcc make libaio-dev g++ git 
		mount -t debugfs none /sys/kernel/debug
			
	elif [[ $DISTRO =~ "CentOS Linux release 7" ]];
	then
		LogMsg "INFO:  Detected CentOS 7.x"
		LogMsg "INFO: installing required packages"
		rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		yum -y --nogpgcheck install wget sysstat mdadm blktrace libaio gcc make libaio-dev g++ git 
		mount -t debugfs none /sys/kernel/debug

	elif [[ $DISTRO =~ "SUSE Linux Enterprise Server 12" ]];
	then
		LogMsg "INFO: Detected SLES12"
		LogMsg "INFO: installing required packages"
		zypper addrepo http://download.opensuse.org/repositories/benchmark/SLE_12_SP3_Backports/benchmark.repo
		zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys refresh
		zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys remove gettext-runtime-mini-0.19.2-1.103.x86_64
		zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys install sysstat
		zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys install grub2
		zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys install wget mdadm blktrace libaio1 gcc make libaio-dev g++ git 
	else
		LogMsg "Error: Unknown Distro"
		UpdateTestState "TestAborted"
		UpdateSummary "Unknown Distro, test aborted"
		return 1
	fi
}

CreateRAID0()
{	
	disks=$(ls -l /dev | grep sd[c-z]$ | awk '{print $10}')

	LogMsg "INFO: Check and remove RAID first"
	mdvol=$(cat /proc/mdstat | grep "active raid" | awk {'print $1'})
	if [ -n "$mdvol" ]; then
		echo "/dev/${mdvol} already exist...removing first"
		umount /dev/${mdvol}
		mdadm --stop /dev/${mdvol}
		mdadm --remove /dev/${mdvol}
		mdadm --zero-superblock /dev/sd[c-z][1-5]
	fi
	
	LogMsg "INFO: Creating Partitions"
	count=0
	for disk in ${disks}
	do		
		LogMsg "INFO: formatting disk /dev/${disk}"
		echo "formatting disk /dev/${disk}"
		(echo d; echo n; echo p; echo 1; echo; echo; echo t; echo fd; echo w;) | fdisk /dev/${disk}
		count=$(( $count + 1 ))
		sleep 1
	done
	LogMsg "INFO: Creating RAID of ${count} devices."
	sleep 1
	mdadm --create ${mdVolume} --level 0 --raid-devices ${count} /dev/sd[c-z][1-5]
	sleep 1
	time mkfs -t $1 -F ${mdVolume}
	mkdir -p ${mountDir}
	sleep 1
	mount -o nobarrier ${mdVolume} ${mountDir}
	if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to create raid"            
            exit 1
	else
		LogMsg "INFO: ${mdVolume} mounted to ${mountDir} successfully."
	fi
}

CreateLVM()
{	
	disks=$(ls -l /dev | grep sd[c-z]$ | awk '{print $10}')

	LogMsg "INFO: Check and remove LVM first"
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
		LogMsg "INFO: formatting disk /dev/${disk}"
		echo "formatting disk /dev/${disk}"
		(echo d; echo n; echo p; echo 1; echo; echo; echo t; echo fd; echo w;) | fdisk /dev/${disk}
		count=$(( $count + 1 )) 
	done
	
	LogMsg "INFO: Creating LVM with all data disks"
	pvcreate /dev/sd[c-z][1-5]
	vgcreate ${vggroup} /dev/sd[c-z][1-5]
	lvcreate -l 100%FREE -i 12 -I 64 ${vggroup} -n lv1
	time mkfs -t $1 -F /dev/${vggroup}/lv1
	mkdir -p ${mountDir}
	mount -o nobarrier /dev/${vggroup}/lv1 ${mountDir}
	if [ $? -ne 0 ]; then
		LogMsg "Error: Unable to create LVM "            
		exit 1
	fi
}


InstallDiskSpd()
{
	LogMsg "'diskspd' installation started..."
	InstallDependencies
	git clone https://github.com/Microsoft/diskspd-for-linux.git
	cd diskspd-for-linux
	make
	make install 
	if [[ `which diskspd` == "" ]]
    then
        LogMsg "Error: 'diskspd' installation failed..."
        exit -1
    fi
}

DiskspdParser ()
{
	if [[ $# != 2 ]];
	then
		LogMsg "Error: Usage $0 <output csv file name> <Absolute path to the diskspd logs folder>"
		echo "Usage $0 <output csv file name> <Absolute path to the diskspd logs folder>"
		exit 1
	fi
	csv_file=$1
	logs_path=$2
	csv_file_tmp=/tmp/temp.txt
	echo $csv_file
	rm -rf $csv_file_tmp $csv_file

	echo "Iteration,TestType,BlockSize,Threads,Jobs,TotalIOPS,ReadIOPS,WriteIOPS,TotalBw(MBps),ReadBw(MBps),WriteBw(MBps),TotalAvgLat,ReadAvgLat,WriteAvgLat,TotalLatStdDev,ReadLatStdDev,WriteLatStdDev,IOmode" > $csv_file

	out_list=(`ls $logs_path/*`)
	count=0
	while [ "x${out_list[$count]}" != "x" ]
	do
		file_name=${out_list[$count]}

		Iteration=`cat $file_name| grep "Iteration:"| awk '{print $2}'| head -1`
		Jobs=`cat $file_name| grep "number of outstanding"|awk '{print $6}'|head -1|sed s/[^0-9]//g`
		
		ReadIOPS=`cat $file_name| grep "total:"|awk '{print $8}'|head -2 |tail -1`
		ReadAvgLat=`cat $file_name| grep "total:"|awk '{print $12}'|head -2 |tail -1`
		ReadLatStdDev=`cat $file_name| grep "total:"|awk '{print $14}'|head -2 |tail -1`
		ReadBw=`cat $file_name| grep "total:"|awk '{print $6}'|head -2 |tail -1`
		
		WriteIOPS=`cat $file_name| grep "total:"|awk '{print $8}'|tail -1`
		WriteAvgLat=`cat $file_name| grep "total:"|awk '{print $12}'|tail -1`
		WriteLatStdDev=`cat $file_name| grep "total:"|awk '{print $14}'|tail -1`
		WriteBw=`cat $file_name| grep "total:"|awk '{print $6}'|tail -1`
		
		BlockSize=`cat $file_name| grep "block size:"|awk '{print $3}'| awk '{printf "%d\n", $1/1024}'| head -1`K
		mode=`cat $file_name| grep "performing"|awk '{print $6}'| sed s/[^0-9]//g`
		testmode=""
		if [[ $mode =~ "0100" ]];
		then
			testmode='write'
		elif [[ $mode =~ "1000" ]];
		then
			testmode='read'
		else
			testmode='readwrite'
		fi
		TestType=`cat $file_name| grep "using.*:"|awk '{print $2}'| head -1`-$testmode
		Threads=`cat $file_name| grep "total threads"|awk '{print $3}'`
		
		TotalIOPS=`cat $file_name| grep "total:"|awk '{print $8}'|head -1`
		TotalAvgLat=`cat $file_name| grep "total:"|awk '{print $12}'|head -1`
		TotalLatStdDev=`cat $file_name| grep "total:"|awk '{print $14}'|head -1`
		TotalBw=`cat $file_name| grep "total:"|awk '{print $6}'|head -1`
		
		IOmode=`cat $file_name | grep "using O_"| sed "s/.*[a-z] //g" | tr '\n' ' - '`
		echo "$Iteration,$TestType,$BlockSize,$Threads,$Jobs,$TotalIOPS,$ReadIOPS,$WriteIOPS,$TotalBw,$ReadBw,$WriteBw,$TotalAvgLat,$ReadAvgLat,$WriteAvgLat,$TotalLatStdDev,$ReadLatStdDev,$WriteLatStdDev,$IOmode" >> $csv_file_tmp

		((count++))
	done

	cat $csv_file_tmp | sort -n| sed 's/^,,.*//' >> $csv_file
	echo "Parsing completed!" 
}

if [[ `which diskspd` == "" ]]
then
	InstallDiskSpd
else
	LogMsg "'diskspd' is already installed"
fi


# Execution of script starts from here
LogMsg "INFO: Execution of script Started..."

HOMEDIR="/root"
LOGDIR="$HOMEDIR/DiskspdLogs"
LOGFILE=$LOGDIR/diskspd.log
IOSTATLOGDIR="${LOGDIR}/iostatLog"
CONSTANTS_FILE="$HOMEDIR/constants.sh"
vggroup="vg1"
mountDir=/ioDiskTest
testfile=/ioDiskTest/testfile


if [ -d "$LOGDIR" ]; then
	mv $LOGDIR $LOGDIR-$(date +"%m%d%Y-%H%M%S")/
fi

mkdir -p $LOGDIR/diskspdLog
mkdir -p $LOGDIR/iostatLog
mkdir -p $LOGDIR/blktraceLog

DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`
if [[ $DISTRO =~ "SUSE Linux Enterprise Server 12" ]];
then
	mdVolume="/dev/md/mdauto0"
else
	mdVolume="/dev/md0"
fi

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    LogMsg "INFO: NO test config provided, So test starting with default config.."
    # These are supposed to be passed from constant.sh
	modes='randread randwrite read write'
	startThread=1
	maxThread=1024
	startIO=4
	maxIO=1024
	numjobs=1
	fileSize=512G
	ioruntime=300
fi

#Install required packages for test
InstallDependencies

#Creating RAID before triggering test
CreateRAID0 ext4
#CreateLVM ext4

# DiskSpd test will starts from here
LogMsg "*********INFO: Starting test execution*********"
UpdateTestState ICA_TESTRUNNING
iteration=0
io_increment=256
ulimitVal=51200

LogMsg "INFO: Preparing files for test..."
diskspd -w0 -b1M -o128 -t1 -c$fileSize -Sh  -L $testfile >>  ${HOMEDIR}/runlog.txt
LogMsg "INFO: Preparing files for test...done!"

for mode in $modes
do
	testmode=""
	if [[ $mode =~ "read" ]];
	then
		testmode='w0'
	elif [[ $mode =~ "write" ]];
	then
		testmode='w100'
	else
		LogMsg "INFO: Unknown testmode: "$mode
	fi

	if [[ $mode =~ "rand" ]];
	then
		testmode="$testmode -r "
	fi

	io=$startIO
	while [ $io -le $maxIO ]
	do
		Thread=$startThread			
		while [ $Thread -le $maxThread ]
		do
			if [ $Thread -ge 8 ]
			then
				numjobs=8
			else
				numjobs=$Thread
			fi
			iostatfilename="${IOSTATLOGDIR}/iostat-diskspd-${mode}-${io}K-${Thread}td.txt"
			nohup iostat -x $ioruntime -t -y > $iostatfilename &
			LOGFILE=$HOMEDIR/DiskspdLogs/diskspdLog/diskspd_b${io}K_${mode}_t${Thread}_o${numjobs}.log
			CMD="diskspd -b${io}K -f$fileSize -$testmode -Sh -W2 -d$ioruntime -L -D -t$Thread -o$numjobs $testfile -xk"
			LogMsg "INFO: Iteration: $iteration  ,command: '$CMD'" 
			echo "Iteration: $iteration  ,command: '$CMD'"  > $LOGFILE 
			if [ $Thread -ge 1024 ]
			then
				ulimit -n $ulimitVal && ulimit -a && $CMD >> $LOGFILE
				ulimitVal=$(( ulimitVal * 2 ))
				ulimit -n 1024
			else
				ulimit -a && $CMD >> $LOGFILE
			fi
			
			iostatPID=`ps -ef | awk '/iostat/ && !/awk/ { print $2 }'`
			kill -9 $iostatPID
			Thread=$(( Thread*2 ))		
			iteration=$(( iteration+1 ))
			sleep 1
		done
		io=$(( io * io_increment ))
	done
done

# Parse DiskSpd results.
DiskspdParser $HOMEDIR/DiskspdResults.csv $HOMEDIR/DiskspdLogs/diskspdLog

# Compress all test logs.
compressedFileName="${HOMEDIR}/DiskSpdIOTest-$(date +"%m%d%Y-%H%M%S").tar.gz"
LogMsg "INFO: Please wait...Compressing all results to ${compressedFileName}..."
tar -cvzf $compressedFileName $LOGDIR/

UpdateTestState ICA_TESTCOMPLETED
LogMsg "*********INFO: Script execution reach END. Completed !!!*********"
