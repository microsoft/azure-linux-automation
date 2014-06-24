#!/usr/bin/python

from azuremodules import *

import argparse
import sys

parser = argparse.ArgumentParser()

parser.add_argument('-x', '--client', help='hostname or fqdn', required=True)
#parser.add_argument('-d', '--dig', help='specifies packet count' )
parser.add_argument('-n', '--nslookup', help='specifies packet size')
args = parser.parse_args()

command = 'nslookup ' + args.client

finalCommand = command + ' >>  nslookup.log'



def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Executing Command : %s", command)
    temp = Run(command)
    UpdateState("TestCompleted")
    

#Run('echo "TestStarted" > iperf-client.txt')
RunTest(finalCommand)