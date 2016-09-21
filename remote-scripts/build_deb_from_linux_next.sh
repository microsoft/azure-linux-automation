#!/bin/bash
#
# This script build linuxnext .deb file.  
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
#

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during running of test

CONSTANTS_FILE="constants.sh"

username=`cat /var/log/cloud-init.log | grep Adding| sed "s/.*user //"`
current_kernel=`uname -r`
code_path="/home/$username/code"
. $code_path/azuremodules.sh

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

UpdateTestState()
{
    echo $1 > $code_path/state.txt
}

#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

# #
# # Source the constants.sh file to pickup definitions from
# # the ICA automation
# #
# if [ -e ./$CONSTANTS_FILE ]; then
    # LogMsg "CONSTANTS FILE: $(cat $CONSTANTS_FILE)"
    # source $CONSTANTS_FILE
# else
    # echo "Warn : no ${CONSTANTS_FILE} found"
# fi

if [ -e $code_path/summary.log ]; then
    LogMsg "Cleaning up previous copies of summary.log"
    rm -f $code_path/summary.log
fi



echo "build not started.. " > $code_path/build.log
cd $code_path

# # cat > build_deb_from_linuxNext.sh <<EOL
# # ICA_TESTRUNNING="TestRunning"      # The test is running
# # ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
# # ICA_TESTABORTED="TestAborted"      # Error during setup of test
# # ICA_TESTFAILED="TestFailed"        # Error during running of test

# # CONSTANTS_FILE="constants.sh"

# # LogMsg()
# # {
    # # echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
# # }

# # UpdateTestState()
# # {
    # # echo $1 > ./state.txt
# # }

# # #
# # # Create the state.txt file so ICA knows we are running
# # #
# # LogMsg "Updating test case state to running"
# # UpdateTestState $ICA_TESTRUNNING

# # if [ -e $code_path/summary.log ]; then
    # # LogMsg "Cleaning up previous copies of summary.log"
    # # rm -f $code_path/summary.log
# # fi

# # . $code_path/azuremodules.sh
# # cd $code_path
updaterepos
install_package git-core sysstat gcc make libssl-dev kernel-package
LogMsg "linux next git clone STARTED.."
git clone git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git  #2>&1
if [ $? -ne 0 ]; then
    LogMsg "Error in linux next git clone"
    echo "linux next git clone: Failed" >> $code_path/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi

cd linux-next

## Make config file
LogMsg "Make .config file STARTED.."
cp /boot/config-$current_kernel .config

CONFIG_FILE=.config
yes "" | make oldconfig
sed --in-place=.orig -e s:"# CONFIG_HYPERVISOR_GUEST is not set":"CONFIG_HYPERVISOR_GUEST=y\nCONFIG_HYPERV=y\nCONFIG_HYPERV_UTILS=y\nCONFIG_HYPERV_BALLOON=y\nCONFIG_HYPERV_STORAGE=y\nCONFIG_HYPERV_NET=y\nCONFIG_HYPERV_KEYBOARD=y\nCONFIG_FB_HYPERV=y\nCONFIG_HID_HYPERV_MOUSE=y": ${CONFIG_FILE}
sed --in-place -e s:"CONFIG_PREEMPT_VOLUNTARY=y":"# CONFIG_PREEMPT_VOLUNTARY is not set": ${CONFIG_FILE}
sed --in-place -e s:"# CONFIG_EXT4_FS is not set":"CONFIG_EXT4_FS=y\nCONFIG_EXT4_FS_XATTR=y\nCONFIG_EXT4_FS_POSIX_ACL=y\nCONFIG_EXT4_FS_SECURITY=y": ${CONFIG_FILE}
sed --in-place -e s:"# CONFIG_REISERFS_FS is not set":"CONFIG_REISERFS_FS=y\nCONFIG_REISERFS_PROC_INFO=y\nCONFIG_REISERFS_FS_XATTR=y\nCONFIG_REISERFS_FS_POSIX_ACL=y\nCONFIG_REISERFS_FS_SECURITY=y": ${CONFIG_FILE}
sed --in-place -e s:"# CONFIG_TULIP is not set":"CONFIG_TULIP=y\nCONFIG_TULIP_MMIO=y": ${CONFIG_FILE}

sed --in-place -e s:"CONFIG_STAGING=y":"# CONFIG_STAGING is not set": ${CONFIG_FILE}  #becuase of a recent linux-next build error

yes "" | make oldconfig
if [ $? -ne 0 ]; then
    LogMsg "Error in mkaing .config file"
    echo "make .config: Failed" >> $code_path/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi
export CONCURRENCY_LEVEL=`nproc`

## Build and Install
LogMsg "build STARTED.."
echo "build STARTED.." >> $code_path/build.log
#make-kpkg --append-to-version=.0001 kernel-image --initrd > $code_path/build.log
make-kpkg kernel-image --initrd >> $code_path/build.log
if [ $? -ne 0 ]; then
    LogMsg "Error in making kernel image linux next deb"
    echo "making linux next deb package: Failed" >> $code_path/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi

# # remove_cmd_from_startup "build_deb_from_linuxNext.sh"
# # if [ $? -ne 0 ]; then
    # # LogMsg "Error in remove test file build_deb_from_linuxNext.sh from /etc/rc.local "
    # # echo "remove test file: Failed" >> $code_path/summary.log
    # # UpdateTestState $ICA_TESTFAILED
    # # exit 80
# # fi

#copy linux-next.deb to home directory

cp $code_path/linux-image*.deb /home/$username

LogMsg "Compressing log files.. "
cd $code_path; tar -cvf logs.tar *.*

#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

# # EOL

# # keep_cmd_in_startup "bash $code_path/build_deb_from_linuxNext.sh  > $code_path/full.log"
# # if [ $? -ne 0 ]; then
    # # LogMsg "Error in placing test file build_deb_from_linuxNext.sh at /etc/rc.local "
    # # echo "placing test file: Failed" >> $code_path/summary.log
    # # UpdateTestState $ICA_TESTFAILED
    # # exit 80
# # fi

# # #
# # # Let ICA know we completed successfully
# # #
# # LogMsg "Updating test case state to completed"
# # UpdateTestState $ICA_TESTCOMPLETED
# # #reboot
