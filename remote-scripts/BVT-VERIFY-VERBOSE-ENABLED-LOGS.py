#!/usr/bin/python

from azuremodules import *


import argparse
import sys
import time
import platform
import os

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking log waagent.log...")
    output = Run("grep -i 'iptables -I INPUT -p udp --dport' /var/log/waagent* | wc -l | tr -d '\n'")
    if not (output == "0") :
        RunLog.info('The log file contains the verbose logs')
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('Verify waagent.log fail, the log file does not contain the verbose logs')
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
        if (result == "0") :
            os.system("echo 'Redhat.Redhat.777' | sudo -S service waagent restart")
        else :
            os.system("echo 'Redhat.Redhat.777' | sudo -S systemctl restart waagent")
    time.sleep(60)

Restartwaagent()
RunTest()
