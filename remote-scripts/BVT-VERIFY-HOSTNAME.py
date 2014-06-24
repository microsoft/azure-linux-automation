#!/usr/bin/python

from azuremodules import *


import argparse
import sys
import time
        #for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-e', '--expected', help='specify expected hostname', required=True)

args = parser.parse_args()
                #if no value specified then stop
expectedHostname = args.expected

def RunTest(expectedHost):
    UpdateState("TestRunning")
    RunLog.info("Checking hostname...")
    temp = Run("hostname")
    output = temp
    if (expectedHost in output) :
        RunLog.info('Hostname is set successfully to %s' %expectedHost)
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('Hostname change failed. Current hostname : %s Expected hostname : %s' % (output, expectedHost))
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest(expectedHostname)