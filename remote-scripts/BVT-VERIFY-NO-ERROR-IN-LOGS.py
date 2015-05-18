#!/usr/bin/python

from azuremodules import *


import argparse
import sys
import time
        #for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-e', '--expected', help='specify expected value', required=True)

args = parser.parse_args()
                #if no value specified then stop
expectedValue = "0"

def RunTest(expectedvalue):
    UpdateState("TestRunning")
    RunLog.info("Checking log waagent.log...")
    temp = Run("grep -i error /var/log/waagent.log | grep -v health | wc -l | tr -d '\n'")
    output = temp
    if (expectedvalue == output) :
        RunLog.info('There is no errors in the logs waagent.log')
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('Verify log waagent.log fail. Current value : %s Expected value : %s' % (output, expectedvalue))
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest(expectedValue)