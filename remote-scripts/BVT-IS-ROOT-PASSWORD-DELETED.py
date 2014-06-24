#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking if root password is deleted or not...")
    temp = Run(command)
    timeout = 0
    output = temp
    if ("Root password deleted" in output) :
                    RunLog.info('waagent.log reports that root password is deleted.')
                    ResultLog.info('PASS')
                    UpdateState("TestCompleted")
    else :
                    RunLog.error('root password not deleted.%s', output)
                    ResultLog.error('FAIL')
                    UpdateState("TestCompleted")

RunTest("cat /var/log/waagent.log")
