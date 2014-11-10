#!/usr/bin/python
import re
import time
import imp
import sys
import argparse
from azuremodules import *

parser = argparse.ArgumentParser()
parser.add_argument('-p', '--password', help='password ', required=True, type = str)
parser.add_argument('-s', '--azureshare', help='azureshare file share', required=True, type = str)
parser.add_argument('-m', '--mountpoint', help='mount point for azureshare file share', required=True, type = str)

args = parser.parse_args()
password = args.password
azureshare = args.azureshare
azureshare_mount = args.mountpoint
vm_username = "unknown"
vm_password = "unknown"

#OS dependent variables
current_distro = "unknown"
distro_version = "unknown"
packages_list = "unknown"

def UpdateRepos():
	RunLog.info("Updating repositories")
	#Repo update for current_distro
	if ((current_distro == "ubuntu") or (current_distro == "Debian")):
		Run("echo '"+vm_password+"' | sudo -S apt-get update")
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'centos')):
		Run("echo '"+vm_password+"' | sudo -S yum -y update")
	elif (current_distro == "opensuse") or (current_distro == "SUSE Linux") or (current_distro == "sles"):
		Run("echo '"+vm_password+"' | sudo -S zypper --non-interactive --gpg-auto-import-keys update")
	else:
		RunLog.info("Repo up-gradation failed on:"+ current_distro)
		exit()

def set_variables_OS_dependent():
	global current_distro
	global distro_version
	global packages_list

	[current_distro, distro_version] = DetectDistro()
	 
	if(current_distro == "unknown"):
		RunLog.info("ERROR: Unknown linux distro...\nExiting the Wordpress installation\n")
		Run("echo XFS_TEST_ABORTED > xfstest.log");
		exit()

	packages_list = ["make", "libuuid-devel", "libattr-devel", "libacl-devel", "libaio-devel", "gettext-tools", "gettext", "gcc", "libtool", "automake", "bc"]
	if (current_distro == "ubuntu"):
		packages_list = ["make", "uuid-dev", "libattr1-dev", "libacl1-dev", "libattr1-dev", "libaio-dev", "gettext", "gcc", "libtool", "automake", "bc"]

	RunLog.info( "set_variables_OS_dependent .. [done]")

install_shell_script = """
tar -xvf xfstests.tar
if [ "$?" != 0 ]
then
	echo "FAILED: to extract xfstests.tar "
	exit 1
fi

tar -xvf xfsprogs.tar
if [ "$?" != 0 ]
then
	echo "FAILED: to extract xfsprogs.tar "
	exit 1
fi
echo "xfstests.tar  xfsprogs.tar extracted succesfully!"
echo "Compiling xfsprogs..."
cd xfsprogs
make
echo "installing xfsprogs"
make install-qa

echo "Compiling xfsprogs..."
cd ../xfstests
./configure
make
"""

set_variables_OS_dependent()
UpdateRepos()
for package in packages_list:
	InstallPackage(package)

RunLog.info("Getting the xfstest suite")
ExecMultiCmdsLocalSudo([install_shell_script, ""])
RunLog.info("Getting the xfstest suite.....[done]")

local_config = """export FSTYP=cifs
export TEST_DEV="""+azureshare+"""
export TEST_DIR="""+azureshare_mount+"""
export TEST_FS_MOUNT_OPTIONS='-o vers=2.1,username=ostcsmbtest,password='"""+password+"""',dir_mode=0777,file_mode=0777'

"""

f = open('xfstests/local.config', 'w')
f.write(local_config)
f.close()
RunLog.info("local.config updated!")

patch_common_rc = """_test_mount() 
{
	_test_options mount
	mount -t cifs """+azureshare+""" """+azureshare_mount+""" -o vers=2.1,username=ostcsmbtest,password='"""+password+"""',dir_mode=0777,file_mode=0777
}

"""
f = open('xfstests/common/rc', 'a')
f.write(patch_common_rc)
f.close()
RunLog.info("xfstests/common/rc updated!")
Run("mkdir "+azureshare_mount)
ExecMultiCmdsLocalSudo(["cd xfstests", "./check -cifs generic/001 generic/002  > ../xfstest.log"])