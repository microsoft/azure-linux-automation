#!/usr/bin/python

import platform
import os.path
import argparse
from azuremodules import *

parser = argparse.ArgumentParser()
parser.add_argument('-r', '--reboot', help='If verify before VM reboot', action="store_true", default=False)
args = parser.parse_args()
reboot = args.reboot

dist = platform.dist()[0]
RunLog.info("OS: " + dist)

def Uninstall():
	RunLog.info("Uninstalling WALinuxAgent")
	if dist == "Ubuntu":
		output = Run("apt-get purge walinuxagent -y")
	elif dist == "CoreOS":
		output = Run("/usr/share/oem/python/bin/python /usr/share/oem/bin/waagent -uninstall")
	else:
		output = Run("waagent -uninstall")
	RunLog.info(output)

def RunTest():
	errCounter = 0
	if dist == "CoreOS":
		wala_conf = "/usr/share/oem/waagent.conf"
	else:
		wala_conf = "/etc/waagent.conf"
	if reboot:
		UpdateState("TestRunning")
		Uninstall()
	
		# verify waagent process is killed
		output = Run("ps -ef | grep -i waagent | grep -v grep | wc -l")
		if int(output) == 0:
			RunLog.info("waagent process is killed.")
		else:
			RunLog.error("Expect waagent process is killed but actually no.")
			errCounter+=1

		# verify config file is deleted
		if os.path.exists(wala_conf):
			RunLog.error("Expect waagent.conf is deleted, but actually no.")
			errCounter+=1
		else:
			RunLog.info("waagent.conf is deleted.")
	else:
		# verify process is not running after reboot
		output = Run("ps -ef | grep -i waagent | grep -v grep | wc -l")
		if int(output) == 0:
			RunLog.info("waagent process is not running after reboot.")
		else:
			RunLog.error("Expect waagent process is not running after reboot but actually yes.")
			errCounter+=1
		UpdateState("TestCompleted")
	print errCounter

RunTest()