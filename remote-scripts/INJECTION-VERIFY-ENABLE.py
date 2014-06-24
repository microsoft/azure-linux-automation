#!/usr/bin/python

from azuremodules import *

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking WALinuxAgent in running processes")

    verifyInstallCmd = "grep 'enableCommand completed' /var/log/waagent.log | wc -l"
    isInstallComplete = RetryOperation( verifyInstallCmd, "Find whether the install completed", "1")

    verifyEnableCmd = "grep 'enableCommand completed' /var/log/waagent.log | wc -l"
    isEnableComplete = RetryOperation( verifyEnableCmd, "Find whether the install completed", "1", 5)

    if (int(isInstallComplete) >= 1 and int(isEnableComplete) >= 1) :
                    RunLog.info('waagent Injection add role completed successfully')
                    ResultLog.info('PASS')
                    UpdateState("TestCompleted")
    else:
                    RunLog.error('waagent Injection add role Failed')
                    ResultLog.Error('FAIL')
                    UpdateState("TestCompleted")

RunTest()
