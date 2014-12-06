#!/usr/bin/python
from azuremodules import *
import sys
import time
import re
import os
import linecache
import imp
import os.path

current_distro	= "unknown"
distro_version	= "unknown"
packages_list	= "unknown"
current_distro = "unknown"

def set_variables_OS_dependent():
	global current_distro
	global distro_version
	global packages_list
	
	RunLog.info ("\nset_variables_OS_dependent ..")
	[current_distro, distro_version] = DetectDistro()

	if(current_distro == 'unknown'):
		RunLog.info ("Unknown distribution found exitting")
		ResultLog.info('ABORTED')
		exit()

	if ((current_distro == "ubuntu") or (current_distro == "Debian")):
		packages_list = ["gcc","libnuma1","libnuma-dev"]
	elif ((current_distro == "rhel") or (current_distro == "Oracle") or (current_distro == 'centos') or (current_distro == 'fedora')):
		packages_list = ["gcc","numactl","numactl-devel"]
	elif ((current_distro == "SUSE") or (current_distro == "opensuse") or (current_distro == "sles")):
		packages_list = ["gcc","libnuma1","libnuma-devel"]

	RunLog.info ("\nset_variables_OS_dependent ..[done]")

def yum_package_install(package):
	if(YumPackageInstall(package) == True):
		return True
	else:
		return False

def zypper_package_install(package):
	if(ZypperPackageInstall(package) == True):
		return True
	else:
		return False

def install_package(package):
	RunLog.info ("\nInstall_package: "+package)
	if (package == "waagent"):
		return install_waagent_from_github()
	else:
		if ((current_distro == "ubuntu") or (current_distro == "Debian")):
			return AptgetPackageInstall(package)
		elif ((current_distro == "rhel") or (current_distro == "Oracle") or (current_distro == 'centos') or (current_distro == 'fedora')):
			return yum_package_install(package)
		elif (current_distro == "SUSE") or (current_distro == "opensuse")or (current_distro == "sles"):
			return zypper_package_install(package)
		else:
			RunLog.info (package + ": package installation failed!")
			RunLog.info (current_distro + ": Unrecognised Distribution OS Linux found!")
			return False

def RunTest():
	UpdateState("TestRunning")
	success = True

	run_stream = '''
	export OMP_NUM_THREADS=`cat /proc/cpuinfo|grep "cpu cores"  |awk '{print $4}'`
	gcc -O3 -std=c99 -fopenmp -lnuma -DN=80000000 -DNTIMES=100 stream.c -o stream-gcc
	if [ $? -ne 0 ]; then
		msg="Error: ./Compile stream.c by gcc failed"
		echo $msg
		echo "${msg}" >> ~/summary.log
		exit 90
	fi

	echo "Starting stream-gcc"

	./stream-gcc > stream-gcc.log
	'''

	for package in packages_list:
		if(not install_package(package)):
			success == False
			break
	
	ExecMultiCmdsLocalSudo([run_stream, ""])
	out=Run("ls stream-gcc.log 2>&1")
	if(out.rfind("No such file or directory") != -1):
		success = False

	if success == True:
		ResultLog.info('PASS')
	else:
		ResultLog.error('FAIL')
	UpdateState("TestCompleted")
#Code execution starts from here
set_variables_OS_dependent()
UpdateRepos(current_distro)

RunTest()

