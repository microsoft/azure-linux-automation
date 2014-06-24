#!/usr/bin/python

import subprocess
import logging
import string
import os

#THIS LOG WILL COLLECT ALL THE LOGS THAT ARE RUN WHILE THE TEST IS GOING ON...
RunLog = logging.getLogger("RuntimeLog : ")
#WRunLog = logging.FileHandler('Runtime.log','a')
RunFormatter = logging.Formatter('%(asctime)s : %(levelname)s : %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
#WRunLog.setFormatter(RunFormatter)
RunLog.setLevel(logging.DEBUG)
RunScreen = logging.StreamHandler()
RunScreen.setFormatter(RunFormatter)
RunLog.addHandler(RunScreen)
#RunLog.addHandler(WRunLog)



#This will collect Result from every test case :
ResultLog = logging.getLogger("Result : ")
WResultLog = logging.FileHandler('Summary.txt','a')
#ResultFormatter = logging.Formatter('%(asctime)s : %(levelname)s : %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
ResultFormatter = logging.Formatter('%(message)s')
WResultLog.setFormatter(ResultFormatter)
ResultLog.setLevel(logging.DEBUG)
ResultScreen = logging.StreamHandler()
ResultScreen.setFormatter(ResultFormatter)
#ResultLog.addHandler(ResultScreen)
ResultLog.addHandler(WResultLog)

global op


def Run(cmd):
        proc=subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        proc.wait()
        op = proc.stdout.read()
        #RunLog.debug(op)
        code=proc.returncode
        int(code)
        #print code
        if code !=0:
            #RunLog.error(op)
            exception = 1
            #updateState('TestFailed')

            
        else:
            #RunLog.info(op)
            #updateState('TestCompleted')
            return op
        if exception == 1:
            str_code = str(code)
            #RunLog.critical("Exception, return code is " + str_code + #" for command " + cmd)
            #return commands.getoutput(cmd)
            return op
def RunTest(server):
    RunLog.info("Killing any iperf servers running..")
    temp = Run("killall iperf")
    RunLog.info("Starting iperf server..")
    temp = Run(server)
    tmp = Run("sleep 3")
    #print(output)
    iperfstatus = open('iperf-server.txt', 'r')
    output = iperfstatus.read()
    #print output
    RunLog.info("Checking if server is started..")
    if ("listening" in output) :
        str_out = string.split(output)
        #len_out = len(str_out)
        for each in str_out :
            #print(each)
            if cmp(each, "listening")==0 :
                RunLog.info("Server started successfully")
                Run('echo "yes" > isServerStarted.txt')
    else :
        RunLog.error('Server Failed to start..')
        Run("echo yes > isServerStarted.txt")
        UpdateState('Aborted')

def UpdateState(testState):
    stateFile = open('state.txt', 'w')
    stateFile.write(testState)
    stateFile.close()

RunTest("nohup iperf -s -i1 > iperf-server.txt &")
