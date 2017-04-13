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
# 
#
# Description:
#######################################################################

#HOW TO PARSE THE ARGUMENTS.. SOURCE - http://stackoverflow.com/questions/4882349/parsing-shell-script-arguments

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

master=$master
slaves=$slaves

#
# Constants/Globals
#
CONSTANTS_FILE="/root/constants.sh"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test
CurrentMachine=""
#######################################################################
#
# LogMsg()
#
#######################################################################
LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> ~/rdmaPreparation.log
}

UpdateTestState()
{
    echo "${1}" > ~/state.txt
}

PrepareForRDMA()
{
	ssh root@${1} "test -e etcHostsEditedSuccessfully"
	if [ $? -ne 0 ]; then
		LogMsg "${1} : Editing /etc/hosts"
		scp etc-hosts.txt root@${1}:
		ssh root@${1} "cat etc-hosts.txt >> /etc/hosts"
		if [ $? -ne 0 ]; then
			LogMsg "${1} : Unable to edit /etc/hosts."
			UpdateTestState $ICA_TESTFAILED
			exit 1
		fi
	fi
	ssh root@${1} touch etcHostsEditedSuccessfully

	LogMsg "${1} : Installing RDMA package..."
	ssh root@${1} yum -y install rdma
	if [ $? -ne 0 ]; then
		LogMsg "${1} : Unable to install RDMA package."
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi
	LogMsg "${1} : Enabling RDMA..."
	ssh root@${1} chkconfig rdma on
	if [ $? -ne 0 ]; then
		LogMsg "${1} : Unable to enable RDMA"
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi

	LogMsg "${1} : Installing required packages..."
	ssh root@${1} yum install -y libmlx4 libibverbs librdmacm
	if [ $? -ne 0 ]; then
		LogMsg "${1} : Unable to install some packges."
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi
	LogMsg "${1} : Installing dapl..."
	ssh root@${1} yum install -y dapl
	if [ $? -ne 0 ]; then
		LogMsg "${1} : Unable to install some packges."
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi

	LogMsg "${1} : Installing IBM binaries.."
	ssh root@${1} test -e platform_mpi-09.01.02.00u.x64.bin
	if [ $? -eq 0 ]; then
		LogMsg "${1} : IBM binary already exists."
	else
		LogMsg "${1} : Downloading https://ciwestus.blob.core.windows.net/linuxbinaries/platform_mpi-09.01.02.00u.x64.bin..."
		ssh root@${1} wget -q https://ciwestus.blob.core.windows.net/linuxbinaries/platform_mpi-09.01.02.00u.x64.bin
		if [ $? -ne 0 ]; then
			LogMsg "${1} : Unable to download platform_mpi-09.01.02.00u.x64.bin"
			UpdateTestState $ICA_TESTFAILED
			exit 1
		fi
	fi
	
	ssh root@${1} test -e /opt/ibm/platform_mpi/bin/mpirun
	if [ $? -eq 0 ]; then
		LogMsg "${1} : IBM binaries already installed"
	else
		ssh root@${1} chmod +x platform_mpi-09.01.02.00u.x64.bin
		LogMsg "${1} : Installing prerequisites..."
		ssh root@${1} yum -y install gcc-c++
		ssh root@${1} yum -y install libgcc.i686
		ssh root@${1} yum -y install glibc.i686
		ssh root@${1} yum -y install libstdc++-4.8.5-4.el7.i686
		ssh root@${1} yum -y install redhat-lsb redhat-lsb*i686
		LogMsg "${1} : Installing platform_mpi-09.01.02.00u.x64.bin..."
		ssh root@${1} ./platform_mpi-09.01.02.00u.x64.bin -i silent
		if [ $? -ne 0 ]; then
			LogMsg "${1} : Unable to install platform_mpi-09.01.02.00u.x64.bin"
			UpdateTestState $ICA_TESTFAILED
			exit 1
		fi
		LogMsg "${1} : IBM binaries installed."
	fi
	
	LogMsg "${1} : Installing Intel MPI binaries on ${1}.."
	ssh root@${1} test -e l_mpi_p_5.1.3.181.tgz
	if [ $? -eq 0 ]; then
		LogMsg "${1} : binary already exists."
	else
		LogMsg "${1} : Downloading https://ciwestus.blob.core.windows.net/linuxbinaries/l_mpi_p_5.1.3.181.tgz..."
		ssh root@${1} wget -q https://ciwestus.blob.core.windows.net/linuxbinaries/l_mpi_p_5.1.3.181.tgz
		if [ $? -ne 0 ]; then
			LogMsg "${1} : Unable to download l_mpi_p_5.1.3.181.tgz"
			UpdateTestState $ICA_TESTFAILED
			exit 1
		fi
	fi
	ssh root@${1} test -d /opt/intel/impi
	if [ $? -eq 0 ]; then
		LogMsg "${1} : Intel binaries already installed."
	else

		ssh root@${1} tar -xvzf l_mpi_p_5.1.3.181.tgz
		ssh root@${1} sed -i '/ACCEPT_EULA/c\ACCEPT_EULA=accept' ./l_mpi_p_5.1.3.181/silent.cfg
		ssh root@${1} sed -i '/ACTIVATION_TYPE/c\ACTIVATION_TYPE=trial_lic' ./l_mpi_p_5.1.3.181/silent.cfg
		LogMsg "${1} : Installing l_mpi_p_5.1.3.181..."
		ssh root@${1} ./l_mpi_p_5.1.3.181/install.sh --silent ./l_mpi_p_5.1.3.181/silent.cfg
		if [ $? -ne 0 ]; then
			LogMsg "${1} : Unable to install Intel MPI binaries."
			cd /root
			UpdateTestState $ICA_TESTFAILED
			exit 1
		fi
		LogMsg "${1} : Intel binaries installed."
	fi
	LogMsg "${1} : Setting up nfs..."
	ssh root@${1} yum -y install nfs-utils.x86_64
	ssh root@${1} mkdir -p /mirror
	ssh root@${1} chmod -R 777 /mirror/
	#ssh root@${1} test -e limits.conf.editedSuccessfully
	#if [ $? -ne 0 ]; then
	#	LogMsg "${1} : Editing /etc/security/limits.conf"
	#	echo "* hard    memlock unlimited" | ssh root@${1} "cat >> /etc/security/limits.conf"
	#	echo "* soft    memlock unlimited" | ssh root@${1} "cat >> /etc/security/limits.conf"
	#	if [ $? -ne 0 ]; then
	#		LogMsg "${1} : Unable to edit /etc/security/limits.conf"
	#		UpdateTestState $ICA_TESTFAILED
	#		exit 1
	#	fi
	#fi
	#ssh root@${1} touch limits.conf.editedSuccessfully
	
	ssh root@${1} rm -rf /etc/exports
	echo '/mirror *(rw,sync)' | ssh root@${1} "cat >> /etc/exports"

	ssh root@${1} systemctl enable rpcbind
	ssh root@${1} systemctl enable nfs-server
	ssh root@${1} systemctl start rpcbind
	ssh root@${1} systemctl start nfs-server
	ssh root@${1} systemctl start nfs-lock
	ssh root@${1} systemctl start nfs-idmap	

	ssh root@${1} touch rdmaPrepared
}

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

if [ "${installLocal}" != "yes" ]; then
	if [ ! ${master} ]; then
		errMsg="Please add/provide value for master in constants.sh. master=<Master VM hostname>"
		LogMsg "${errMsg}"
		echo "${errMsg}" >> ~/summary.log
		UpdateTestState $ICA_TESTABORTED
		exit 1
	fi
	if [ ! ${slaves} ]; then
		errMsg="Please add/provide value for slaves in constants.sh. slaves=<hostname1,hostname2,hostname3>"
		LogMsg "${errMsg}"
		echo "${errMsg}" >> ~/summary.log
		UpdateTestState $ICA_TESTABORTED
		exit 1
	fi
fi

if [ "${rdmaPrepare}" != "yes" ] && [ "${rdmaPrepare}" != "no" ]; then
	errMsg="Please add/provide value for rdmaPrepare in constants.sh. rdmaPrepare=<yes>/<no>"
    LogMsg "${errMsg}"
    echo "${errMsg}" >> ~/summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi
if [ "${rdmaRun}" != "yes" ] && [ "${rdmaRun}" != "no" ]; then
	errMsg="Please add/provide value for rdmaRun in constants.sh. rdmaRun=<yes>/<no>"
    LogMsg "${errMsg}"
    echo "${errMsg}" >> ~/summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

slavesArr=`echo ${slaves} | tr ',' ' '`

if [ "${rdmaPrepare}" == "yes" ]; then

	# master VM preparation for RDMA tests...
	
	if [ ${installLocal} == "yes" ]; then
		localVM=`hostname`
		ssh root@${localVM} test -e rdmaPrepared
		if [ $? -ne 0 ]; then 
			LogMsg "Info : Running config on current machine : '${localVM}'"
			PrepareForRDMA "${localVM}"
		else
			LogMsg "${localVM} is already prepared for RDMA tests." 
		fi
	else
		ssh root@${master} test -e rdmaPrepared
		if [ $? -ne 0 ]; then 
			LogMsg "Info : Running config on master : '${master}'"
			PrepareForRDMA "${master}"
		else
			LogMsg "${master} is already prepared for RDMA tests." 
		fi

		# slave VMs preparation for RDMA tests...
		for slave in $slavesArr
		do
			ssh root@${slave} test -e rdmaPrepared
			if [ $? -ne 0 ]; then 
				LogMsg "Info : Running config on slave '${slave}'"
				PrepareForRDMA "${slave}"
				LogMsg "Info : mounting ${master}:/mirror NFS directory to /mirror on '${slave}'"
				ssh root@${slave} mount ${master}:/mirror /mirror
			else
				LogMsg "${slave} is already prepared for RDMA tests." 
			fi
		done
	fi
else
	LogMsg "Info : Skipping RDMA preparation. (Source : constants.sh)"
fi

if [ "${rdmaRun}" == "yes" ]
then
	mpirunPath=`find / -name mpirun | grep intel64`
	imb_mpi1Path=`find / -name IMB-MPI1 | grep intel64`
	
	LogMsg "Executing test command : ${mpirunPath} -hosts ${master},${slaves} -ppn 2 -n 2 -env I_MPI_FABRICS dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 ${imb_mpi1Path} pingpong > pingPongTestIntraNodeTestOut.txt 2>&1"
	#MPI-pingpong intra node
	$mpirunPath -hosts ${master} -ppn 2 -n 2 -env I_MPI_FABRICS dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 $imb_mpi1Path pingpong > pingPongTestIntraNodeTestOut.txt 2>&1
	sleep 10
	#MPI-pingpong inter node
	LogMsg "Executing test command : $mpirunPath -hosts ${master},${slaves} -ppn 1 -n 2 -env I_MPI_FABRICS dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 $imb_mpi1Path pingpong > pingPongTestInterNodeTestOut.txt 2>&1"
	$mpirunPath -hosts ${master},${slaves} -ppn 1 -n 2 -env I_MPI_FABRICS dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 $imb_mpi1Path pingpong > pingPongTestInterNodeTestOut.txt 2>&1
	
	testExitCode=$?
	if [ $testExitCode -ne 0 ]
	then
		errMsg="Test execution returned exit code ${testExitCode}"
		LogMsg "${errMsg}"
		echo "${errMsg}" >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 1
	else
		UpdateTestState $ICA_TESTCOMPLETED
	fi
fi