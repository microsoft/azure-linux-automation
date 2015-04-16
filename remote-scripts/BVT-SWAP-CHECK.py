#!/usr/bin/python

from azuremodules import *

def RunTest(command):
	UpdateState("TestRunning")
	RunLog.info("Checking if swap disk is enable or not..")
	RunLog.info("Executing swapon -s..")
	temp = Run(command)
	output = temp
	
	RunLog.info("Read ResourceDisk.EnableSwap from /etc/waagent.conf..")
	outputlist=open("/etc/waagent.conf")
	for line in outputlist:
		if(line.find("ResourceDisk.EnableSwap")!=-1):
				break

	RunLog.info("Value ResourceDisk.EnableSwap in /etc/waagent.conf.." + line.strip()[-1])
	if (("swap" in output) and (line.strip()[-1] == "n")):
		RunLog.error('Swap is enabled. Swap should not be enabled.')
		RunLog.error('%s', output)
		ResultLog.error('FAIL')

	elif ((output.find("swap")==-1) and (line.strip()[-1] == "y")):
		RunLog.error('Swap is disabled. Swap should be enabled.')
		RunLog.error('%s', output)
		ResultLog.error('FAIL')
	
	elif(("swap" in output) and (line.strip()[-1] == "y")):
		RunLog.info('swap is enabled.')
		ResultLog.info('PASS')

	elif ((output.find("swap")==-1) and (line.strip()[-1] == "n")):
		RunLog.info('swap is disabled.')
		ResultLog.info('PASS')

	UpdateState("TestCompleted")
RunTest("swapon -s")
