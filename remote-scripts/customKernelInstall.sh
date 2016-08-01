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
LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> ~/build-customKernel.txt
}

UpdateTestState()
{
    echo "${1}" > ~/state.txt
}

if [ -z "$customKernel" ]; then
	echo "Please mention -customKernel next"
	exit 1
fi
touch ~/build-customKernel.txt

LogMsg "Custom Kernel:$customKernel"
chmod +x ~/DetectLinuxDistro.sh
LinuxDistro=`~/DetectLinuxDistro.sh`
if [ $LinuxDistro == "SLES" -o $LinuxDistro == "SUSE" ]; then
    #zypper update
	zypper --non-interactive install git-core make tar gcc bc patch dos2unix wget xz 
	#TBD
elif [ $LinuxDistro == "CENTOS" -o $LinuxDistro == "REDHAT" -o $LinuxDistro == "FEDORA" -o $LinuxDistro == "ORACLELINUX" ]; then
    #yum update
	yum install -y git make tar gcc bc patch dos2unix wget xz
	#TBD
elif [ $LinuxDistro == "UBUNTU" ]; then
	LogMsg "Updating distro..."
	apt-get update
	LogMsg "Installing packages git make tar gcc bc patch dos2unix wget kernel-package..."
	apt-get install -y git make tar gcc bc patch dos2unix wget kernel-package
	if [ "${customKernel}" == "next" ]; then
		rm -rf linux-next
		LogMsg "Downloading kernel source..."
		git clone https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
		cd linux-next
		
		#Download kernel build shell script...
		wget https://raw.githubusercontent.com/simonxiaoss/linux_performance_test/master/git_bisect/build-ubuntu.sh
		chmod +x build-ubuntu.sh
		#Start installing kernel
		LogMsg "Building and Installing kernel..."
		./build-ubuntu.sh  >> ~/build-customKernel.txt 2>&1
		if [ $? -ne 0 ]; then
			LogMsg "CUSTOM_KERNEL_FAIL"
			UpdateTestState $ICA_TESTFAILED
			exit 0
		fi
	else:
		#TBD
	fi
fi
UpdateTestState $ICA_TESTCOMPLETED
sleep 10
LogMsg "CUSTOM_KERNEL_SUCCESS"
sleep 10
exit 0