#!/usr/bin/python

from azuremodules import *

import sys

def RunTest():
    UpdateState("TestRunning")
    if (IsUbuntu()) :
        mntresource = "/mnt"
    else :
        mntresource = "/mnt/resource"
    RunLog.info("creating a file in " + mntresource)
    temp = Run("echo DONE > " + mntresource + "/try.txt")
    temp = Run("cat " + mntresource + "/try.txt")
    output = temp
    if ("DONE" in output) :
        RunLog.info('file is successfully created in /mnt/resource folder.')
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('failed to create file in /mnt/resource folder.')
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest()
