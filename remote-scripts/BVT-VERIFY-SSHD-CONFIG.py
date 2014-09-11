#!/usr/bin/python

from azuremodules import *
import re

sshdFilePath = "/etc/ssh/sshd_config" 
expectedString = "ClientAliveInterval"
commentedLine = "#ClientAliveInterval"

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("ClientAliveInterval into the /etc/ssh/sshd_config file")
    CheckComment =GetStringMatchCount(sshdFilePath,commentedLine)
    if(CheckComment == 0):
		CheckClientInterval = GetStringMatchCount(sshdFilePath,expectedString)
		if(CheckClientInterval == 1):
			sshd_contents = Run("cat /etc/ssh/sshd_config")
			sshd_contents_lines = re.split("\n", sshd_contents)
			for line in sshd_contents_lines:
				if "ClientAliveInterval" in line:
					matchObj = line.split(" ")
					if matchObj[0] == "ClientAliveInterval" and int(matchObj[1]) > 0 and int(matchObj[1]) < 181:
						print ("CLIENT_ALIVE_INTERVAL_SUCCESS")
						RunLog.info('ClientAliveInterval is into the /etc/ssh/sshd_config file.')
						ResultLog.info('PASS')
					else:
						print ("CLIENT_ALIVE_INTERVAL_FAIL")
						RunLog.error("ClientAliveInterval time is more than 180")
						ResultLog.info('FAIL')
		else:
			print ("CLIENT_ALIVE_INTERVAL_FAIL")
			ResultLog.error('FAIL')
			RunLog.info('ClientAliveInterval is not into the /etc/ssh/sshd_config file.')
    else:
		print ("CLIENT_ALIVE_INTERVAL_COMMENTED")
		RunLog.info('ClientAliveInterval is not into the /etc/ssh/sshd_config file.')
		ResultLog.error('FAIL')
		UpdateState("TestCompleted")
RunTest()
	
