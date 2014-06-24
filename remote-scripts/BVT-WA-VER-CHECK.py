#!/usr/bin/python

import argparse
import sys
import re
from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking WALinuxAgent Version")
    output = Run(command)
    ExpectedVersionPattern = "WALinuxAgent\-\d[\.\d]+.*\ running\ on.*"
    RegExp = re.compile(ExpectedVersionPattern)

    if (RegExp.match(output)) :
                    RunLog.info('Waagent is in Latest Version .. - %s', output)
                    ResultLog.info('PASS')
                    UpdateState("TestCompleted")
    else :
                    RunLog.error('Waagent version is differnt than required.')
                    RunLog.error('Current version - %s', output)
                    RunLog.error('Expected version pattern - %s', ExpectedVersionPattern)
                    ResultLog.error('FAIL')
                    UpdateState("TestCompleted")

RunTest("/usr/sbin/waagent --version")
