#!/usr/bin/python

import subprocess
import logging
import string
import os

from azuremodules import *

global op


def CheckServer():
    RunLog.info("Checking server status..")
    iperfstatus = open('iperf-server.txt', 'r')
    output = iperfstatus.read()
    #print output
    RunLog.info("Checking if server was connected to client..")
    if ("connected" in output) :
        str_out = str.split(output)
        #len_out = len(str_out)
        #This for loop in used to check the every word of test output [Future plan]
        for each in str_out :
            #print(each)
            if each == "connected":
                RunLog.info("Server was successfully connected to client.")
                ResultLog.info("PASS")
                break
            
    else :
        RunLog.error('Server did not received any connections from client.')
        ResultLog.info("FAIL")
    
    

CheckServer()
UpdateState("TestCompleted")
#Run('echo "TestCompleted" >> iperf-server.txt')
