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
#
# Constants/Globals
#
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test

#######################################################################
#
# LogMsg()
#
#######################################################################

if [ -z "$customKernel" ]; then
	echo "Please mention -customKernel next"
	exit 1
fi
if [ -z "$logFolder" ]; then
	logFolder="~/"
	echo "-logFolder is not mentioned. Using ~/"
else
	echo "Using Log Folder $logFolder"
fi

LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> /$logFolder/build-customKernel.txt
}

UpdateTestState()
{
    echo "${1}" > /$logFolder/state.txt
}


touch /$logFolder/build-customKernel.txt

if [ "${customKernel}" == "linuxnext" ]; then
	kernelSource="https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
	sourceDir="linux-next"
elif [ "${customKernel}" == "netnext" ]; then
	kernelSource="https://git.kernel.org/pub/scm/linux/kernel/git/davem/net-next.git"
	sourceDir="net-next"
elif [[ $customKernel == *.deb ]]; then
	LogMsg "Custom Kernel:$customKernel"
	apt-get update
	apt-get install wget
	LogMsg "Debian package web link detected. Downloading $customKernel"
	wget $customKernel
	LogMsg "Installing ${customKernel##*/}"
	dpkg -i "${customKernel##*/}"
	kernelInstallStatus=$?
	UpdateTestState $ICA_TESTCOMPLETED
	if [ $kernelInstallStatus -ne 0 ]; then
		LogMsg "CUSTOM_KERNEL_FAIL"
		UpdateTestState $ICA_TESTFAILED
	else
		LogMsg "CUSTOM_KERNEL_SUCCESS"
		UpdateTestState $ICA_TESTCOMPLETED
	fi
	exit 0
elif [[ $customKernel == *.rpm ]]; then
	LogMsg "Custom Kernel:$customKernel"
	yum -y install wget
	LogMsg "RPM package web link detected. Downloading $customKernel"
	wget $customKernel
	LogMsg "Installing ${customKernel##*/}"
	rpm -ivh "${customKernel##*/}"
	kernelInstallStatus=$?
	UpdateTestState $ICA_TESTCOMPLETED
	if [ $kernelInstallStatus -ne 0 ]; then
		LogMsg "CUSTOM_KERNEL_FAIL"
		UpdateTestState $ICA_TESTFAILED
	else
		LogMsg "CUSTOM_KERNEL_SUCCESS"
		UpdateTestState $ICA_TESTCOMPLETED
	fi
	exit 0
fi
LogMsg "Custom Kernel:$customKernel"
chmod +x /$logFolder/DetectLinuxDistro.sh
LinuxDistro=`/$logFolder/DetectLinuxDistro.sh`
if [ $LinuxDistro == "SLES" -o $LinuxDistro == "SUSE" ]; then
    #zypper update
	zypper --non-interactive install git-core make tar gcc bc patch dos2unix wget xz 
	#TBD
elif [ $LinuxDistro == "CENTOS" -o $LinuxDistro == "REDHAT" -o $LinuxDistro == "FEDORA" -o $LinuxDistro == "ORACLELINUX" ]; then
    #yum update
	yum install -y git make tar gcc bc patch dos2unix wget xz
	#TBD
elif [ $LinuxDistro == "UBUNTU" ]; then
	unset UCF_FORCE_CONFFOLD
	export UCF_FORCE_CONFFNEW=YES
	export DEBIAN_FRONTEND=noninteractive
	ucf --purge /etc/kernel-img.conf
	export DEBIAN_FRONTEND=noninteractive
	LogMsg "Updating distro..."
	apt-get update
	LogMsg "Installing packages git make tar gcc bc patch dos2unix wget ..."
	apt-get install -y git make tar gcc bc patch dos2unix wget >> /$logFolder/build-customKernel.txt 2>&1
	LogMsg "Installing kernel-package ..."
	apt-get -o Dpkg::Options::="--force-confnew" -y install kernel-package >> /$logFolder/build-customKernel.txt 2>&1
	rm -rf linux-next
	LogMsg "Downloading kernel source..."
	git clone ${kernelSource} >> /$logFolder/build-customKernel.txt 2>&1
	cd ${sourceDir}
	
	#Download kernel build shell script...
	wget https://raw.githubusercontent.com/simonxiaoss/linux_performance_test/master/git_bisect/build-ubuntu.sh
	chmod +x build-ubuntu.sh
	#Start installing kernel
	LogMsg "Building and Installing kernel..."
	./build-ubuntu.sh  >> /$logFolder/build-customKernel.txt 2>&1
	if [ $? -ne 0 ]; then
		LogMsg "CUSTOM_KERNEL_FAIL"
		UpdateTestState $ICA_TESTFAILED
		exit 0
	fi

fi
UpdateTestState $ICA_TESTCOMPLETED
sleep 10
LogMsg "CUSTOM_KERNEL_SUCCESS"
sleep 10
exit 0
