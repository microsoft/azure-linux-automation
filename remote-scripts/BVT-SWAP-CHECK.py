#!/usr/bin/python

from azuremodules import *

def RunTest(command):
	UpdateState("TestRunning")
	RunLog.info("Checking if swap disk is enable or not..")
	RunLog.info("Executing swapon -s..")
	temp = Run(command)
	output = temp
	if ("swap" in output) :
		RunLog.error('Swap is enabled. Swap should not be enabled.')
		RunLog.error('%s', output)
		ResultLog.error('FAIL')
		UpdateState("TestCompleted")
	else :
		RunLog.info('swap is disabled.')
		ResultLog.info('PASS')
		UpdateState("TestCompleted")

RunTest("swapon -s")
