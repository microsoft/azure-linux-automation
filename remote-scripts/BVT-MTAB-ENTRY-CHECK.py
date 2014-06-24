#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking for resource disk entry in /etc/mtab.")
    output = Run(command)
    if (IsUbuntu()) :
        mntresource = "/dev/sdb1 /mnt"
    else :
        mntresource = "/dev/sdb1 /mnt/resource"

    if (mntresource in output) :
        RunLog.info('Resource disk entry is present.')
        ResultLog.info('PASS')
        str_out = output.splitlines()
        #len_out = len(str_out)
        for each in str_out :
            #print(each)
            if (mntresource in each) :
                RunLog.info("%s", each)

        UpdateState("TestCompleted")

    else :
        RunLog.error('Resource disk entry is not present.')
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest("cat /etc/mtab")
