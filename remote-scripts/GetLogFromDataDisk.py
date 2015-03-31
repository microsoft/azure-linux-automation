#!/usr/bin/python

import sys
import os
import subprocess
import shutil
import re
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-u', '--username', help='please input the user name ', required=True, type = str)
args = parser.parse_args()
username = args.username

def Run(cmd):
        proc=subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        proc.wait()
        op = proc.stdout.read()
        code=proc.returncode
        int(code)
        if code !=0:
            exception = 1
        else:
            return op
        if exception == 1:
            str_code = str(code)
            return op

output = Run("fdisk -l | grep /dev/sdc")
output = output.strip()
outputlist = re.split("\n", output)
diskname = outputlist[-1][:9]
print diskname

os.makedirs("/mnt2")

subprocess.call(["mount", diskname, "/mnt2"])

syslog_path = "/mnt2/var/log/syslog"
message_path = "/mnt2/var/log/messages"
waagent_path = "/mnt2/var/log/waagent.log"
dmesg_path = "/mnt2/var/log/dmesg"

message_log = "/home/" + username + "/messages.log"
waagent_log = "/home/" + username + "/waagent.log"
dmesg_log = "/home/" + username + "/dmesg.log"

Run("touch " + message_log)
Run("touch " + waagent_log)
Run("touch " + dmesg_log)

if (os.path.exists(syslog_path)):
	shutil.copyfile(syslog_path, message_log)
elif (os.path.exists(message_path)):
	shutil.copyfile(message_path, message_log)
if (os.path.exists(waagent_path)):
	shutil.copyfile(waagent_path, waagent_log)	
if (os.path.exists(dmesg_path)):
	shutil.copyfile(dmesg_path, dmesg_log)
	


