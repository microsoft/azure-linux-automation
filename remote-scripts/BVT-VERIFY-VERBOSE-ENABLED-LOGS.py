#!/usr/bin/python

from azuremodules import *


import argparse
import sys
import time
import platform
import os
#for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-e', '--expected', help='specify expected value', required=True)

args = parser.parse_args()
#if no value specified then stop
expectedValue = "1"
def RunTest(expectedvalue):
    UpdateState("TestRunning")
    RunLog.info("Checking log waagent.log...")
    temp = Run("grep -i 'iptables -I INPUT -p udp --dport' /var/log/waagent* | wc -l | tr -d '\n'")
    output = temp
        
    if (expectedvalue == output) :
        RunLog.info('The log file contains the expected value')
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('Verify waagent.log fail. Current value : %s Expected value : %s' % (output, expectedvalue))
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")
def Restartwaagent():
    distro = platform.dist()
    if (distro[0] == "CoreOS") :
        Run("echo 'Redhat.Redhat.777' | sudo -S sed -i s/Logs.Verbose=n/Logs.Verbose=y/g  /usr/share/oem/waagent.conf")
    else :
        Run("echo 'Redhat.Redhat.777' | sudo -S sed -i s/Logs.Verbose=n/Logs.Verbose=y/g  /etc/waagent.conf")
    RunLog.info("Restart waagent service...")
    result = Run("echo 'Redhat.Redhat.777' | sudo -S find / -name systemctl |wc -l | tr -d '\n'")    
    if (distro[0] == "Ubuntu") :
        Run("echo 'Redhat.Redhat.777' | sudo -S service walinuxagent restart")
    else :
#for distro: centos6,oracle6 it will be hung when call Run,so use os.system() to replace it
        if (result == "0") :
            os.system("echo 'Redhat.Redhat.777' | sudo -S service waagent restart")
        else :
            os.system("echo 'Redhat.Redhat.777' | sudo -S systemctl restart waagent")
Restartwaagent()
time.sleep(60)
RunTest(expectedValue)
