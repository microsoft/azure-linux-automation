#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking resource disc...")
    if (IsUbuntu()) :
        mntresource = "/dev/sdb1 on /mnt"
    else :
        mntresource = "/dev/sdb1 on /mnt/resource"
    temp = Run(command)
    timeout = 0
    output = temp
    if (mntresource in output) :
        RunLog.info('Resource disk is mounted successfully.')
        if ("ext4" in output) :
            RunLog.info('Resource disk is mounted as ext4')
        elif ("ext3" in output) :
            RunLog.info('Resource disk is mounted as ext3')
        else :
            RunLog.info('Unknown filesystem detected for resource disk')
            ResultLog.info("FAIL")
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('Resource Disk mount check failed. Mount out put is: %s', output)
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest("mount")
