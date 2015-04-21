#!/usr/bin/python

from azuremodules import *
import os.path

def RunTest(command):
	UpdateState("TestRunning")
	RunLog.info("Checking if swap disk is enable or not..")
	RunLog.info("Executing swapon -s..")
	temp = Run(command)
	output = temp

	if os.path.exists("/etc/lsb-release") and int(Run("cat /etc/lsb-release | grep -i coreos | wc -l")) > 0:
		waagent_conf_file = "/usr/share/oem/waagent.conf"
	else:
		waagent_conf_file = "/etc/waagent.conf"

	RunLog.info("Read ResourceDisk.EnableSwap from " + waagent_conf_file + "..")
	outputlist=open(waagent_conf_file)

	for line in outputlist:
		if(line.find("ResourceDisk.EnableSwap")!=-1):
				break

	RunLog.info("Value ResourceDisk.EnableSwap in " + waagent_conf_file + ": " + line.strip()[-1])
	if (("swap" in output) and (line.strip()[-1] == "n")):
		RunLog.error('Swap is enabled. Swap should not be enabled.')
		RunLog.error('%s', output)
		ResultLog.error('FAIL')

	elif ((output.find("swap")==-1) and (line.strip()[-1] == "y")):
		RunLog.error('Swap is disabled. Swap should be enabled.')
		RunLog.error('%s', output)
		RunLog.info("Pleae check value of setting ResourceDisk.SwapSizeMB")
		ResultLog.error('FAIL')
	
	elif(("swap" in output) and (line.strip()[-1] == "y")):
		RunLog.info('swap is enabled.')
		if(IsUbuntu()) :
			mntresource = "/mnt"
		else:
			mntresource = "/mnt/resource"
		swapfile = mntresource + "/swapfile"
		if(swapfile in output):
			RunLog.info("swap is enabled on resource disk")
			ResultLog.info('PASS')
		else:
			RunLog.info("swap is not enabled on resource disk")
			ResultLog.info('FAIL')
	elif((output.find("swap")==-1) and (line.strip()[-1] == "n")):
		RunLog.info('swap is disabled.')
		ResultLog.info('PASS')
	UpdateState("TestCompleted")

RunTest("swapon -s")

