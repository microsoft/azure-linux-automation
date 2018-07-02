#!/bin/bash
#######################################################################
# perf_syscallBenchmark.sh
# Author : Maruthi Sivakanth Rebba <v-sirebb@microsoft.com>
#
# Description:
#    Download and run syscall benchmark test.
#    
# Supported Distros:
#    Ubuntu, SUSE, RedHat, CentOS
#######################################################################

HOMEDIR="/root"
LogMsg()
{
    echo "[$(date +"%x %r %Z")] ${1}"
	echo "[$(date +"%x %r %Z")] ${1}" >> "${HOMEDIR}/syscallTestLog.txt"
}
LogMsg "Sleeping 10 seconds.."
sleep 10

#export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/oem/bin:/usr/share/oem/python/bin:/opt/bin
CONSTANTS_FILE="$HOMEDIR/constants.sh"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test

UpdateTestState()
{
    echo "${1}" > $HOMEDIR/state.txt
}

InstallDependencies() {
		DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`

		if [[ $DISTRO =~ "Ubuntu" ]] || [[ $DISTRO =~ "Debian" ]];
		then
			LogMsg "Detected UBUNTU/Debian"
			until dpkg --force-all --configure -a; sleep 10; do echo 'Trying again...'; done
			apt-get update
			apt-get install -y gcc yasm tar wget dos2unix git
			if [ $? -ne 0 ]; then
				LogMsg "Error: Unable to install SysCall required packages"
				exit 1
			fi							
		elif [[ $DISTRO =~ "Red Hat Enterprise Linux Server release 6" ]] || [[ $DISTRO =~ "Debian" ]];
		then
			LogMsg "Detected RHEL 6.x"
			LogMsg "INFO: installing required packages"
			rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
			yum -y --nogpgcheck install gcc yasm tar wget dos2unix git
			if [ $? -ne 0 ]; then
				LogMsg "Error: Unable to install SysCall required packages"
				exit 1
			fi
		elif [[ $DISTRO =~ "Red Hat Enterprise Linux Server release 7" ]];
		then
			LogMsg "Detected RHEL 7.x"
			LogMsg "INFO: installing required packages"
			rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
			yum -y --nogpgcheck install gcc yasm tar wget dos2unix git
			if [ $? -ne 0 ]; then
				LogMsg "Error: Unable to install SysCall required packages"
				exit 1
			fi		
		elif [[ $DISTRO =~ "CentOS Linux release 6" ]] || [[ $DISTRO =~ "CentOS release 6" ]];
		then
			LogMsg "Detected CentOS 6.x"
			LogMsg "INFO: installing required packages"
			rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
			yum -y --nogpgcheck install gcc yasm tar wget dos2unix git
			if [ $? -ne 0 ]; then
				LogMsg "Error: Unable to install SysCall required packages"
				exit 1
			fi	
		elif [[ $DISTRO =~ "CentOS Linux release 7" ]];
		then
			LogMsg "Detected CentOS 7.x"
			LogMsg "INFO: installing required packages"
			rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
			yum -y --nogpgcheck install gcc yasm tar wget dos2unix git
			if [ $? -ne 0 ]; then
				LogMsg "Error: Unable to install SysCall required packages"
				exit 1
			fi
		elif [[ $DISTRO =~ "SUSE Linux Enterprise Server 12" ]];
		then
			LogMsg "Detected SLES12"
			zypper addrepo http://download.opensuse.org/repositories/benchmark/SLE_12_SP3_Backports/benchmark.repo
			zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys refresh
			#zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys remove gettext-runtime-mini-0.19.2-1.103.x86_64
			zypper --no-gpg-checks --non-interactive --gpg-auto-import-keys install gcc yasm tar wget dos2unix git
			if [ $? -ne 0 ]; then
				LogMsg "Error: Unable to install SysCall required packages"
				exit 1
			fi
		else
			LogMsg "Unknown Distro"
			UpdateTestState "TestAborted"
			UpdateSummary "Unknown Distro, test aborted"
			return 1
	fi
}

runSysCallBenchmark()
{
	UpdateTestState ICA_TESTRUNNING
	#Syscall benchmark test start..
	LogMsg "git clone SysCall benchmark started..."
	git clone https://github.com/arkanis/syscall-benchmark.git
	cd syscall-benchmark && ./compile.sh
	if [ $? -ne 0 ]; then
		LogMsg "Error: Unable to install SysCall check logs for more details."
		exit 1
	fi
	LogMsg "INFO: SysCall benchmark install SUCCESS"
	LogMsg "SysCall benchmark test started..."
	./bench.sh
	if [ $? -ne 0 ]; then
		LogMsg "Error: SysCall benchmark test run FAILED"
		exit 1
	fi
	LogMsg "INFO: SysCall benchmark test run SUCCESS"
	cp $LOGDIR/results.log ${HOMEDIR}/
	compressedFileName="${HOMEDIR}/syscall-benchmark-$(date +"%m%d%Y-%H%M%S").tar.gz"
	LogMsg "INFO: Please wait...Compressing all results to ${compressedFileName}..."
	tar -cvzf $compressedFileName  ${HOMEDIR}/*.txt ${HOMEDIR}/*.log ${HOMEDIR}/*.csv $LOGDIR/

	echo "Test logs are located at ${LOGDIR}"
	UpdateTestState ICA_TESTCOMPLETED
}

############################################################
#	Main body
############################################################
LogMsg "*********INFO: Starting test setup*********"
HOMEDIR=$HOME
mv $HOMEDIR/syscall-benchmark/ $HOMEDIR/syscall-benchmark-$(date +"%m%d%Y-%H%M%S")/
LOGDIR="${HOMEDIR}/syscall-benchmark"

cd ${HOMEDIR}
#Install required packages for SysCall benchmark
InstallDependencies

#Run SysCall benchmark test
LogMsg "*********INFO: Starting test execution*********"
runSysCallBenchmark
LogMsg "*********INFO: Script execution reach END. Completed !!!*********"
