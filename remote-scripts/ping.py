#!/usr/bin/python

from azuremodules import *

import argparse
import sys

parser = argparse.ArgumentParser()

parser.add_argument('-x', '--client', help='time to run ping', required=True)
parser.add_argument('-c', '--count', help='specifies packet count', type= int)
parser.add_argument('-s', '--size', help='specifies packet size', type= int)
parser.add_argument('-w', '--wait', help='timeout in seconds for each packet', type= int)
parser.add_argument('-t', '--ttl', help='time to run ping', type= int)
args = parser.parse_args()

command = 'ping ' + args.client
if args.size != None :
        command = command + ' -s' + str(args.size)
if args.wait != None:
        command = command + ' -w' + str(args.wait)
if args.count != None :
        command = command + ' -c' + str(args.count)
if args.ttl != None:
        command = command + ' -t' + str(args.ttl)
finalCommand = command + ' >>  ping.log'



def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Executing Command : %s", command)
    temp = Run(command)
    UpdateState("TestCompleted")
    

#Run('echo "TestStarted" > iperf-client.txt')
RunTest(finalCommand)
