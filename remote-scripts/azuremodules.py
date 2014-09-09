#!/usr/bin/python
#####################################################################################################################################
# THIS FILE CONTAINS ALL THE FUNCTIONS USED IN PYTHON TEST FILES... HANDLE WITH CARE...
# FOR ANY QUERY - V-SHISAV@MICROSOFT.COM
# DO NOT DELETE ANY STATEMENT FROM THE FUNCTION EVEN IF IT IS COMMENTED!!! BECAUSE I'M TRACKING, WHAT I'M DOING...
#####################################################################################################################################

import subprocess
import logging
import string
import os
import commands
import time
import os.path
import array
#added v-sirebb
import linecache
import sys
import re

#THIS LOG WILL COLLECT ALL THE LOGS THAT ARE RUN WHILE THE TEST IS GOING ON...
RunLog = logging.getLogger("RuntimeLog : ")
WRunLog = logging.FileHandler('Runtime.log','w')
RunFormatter = logging.Formatter('%(asctime)s : %(levelname)s : %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
WRunLog.setFormatter(RunFormatter)
RunLog.setLevel(logging.DEBUG)
RunScreen = logging.StreamHandler()
RunScreen.setFormatter(RunFormatter)
#RunLog.addHandler(RunScreen)
RunLog.addHandler(WRunLog)

#This will collect Result from every test case :
ResultLog = logging.getLogger("Result : ")
WResultLog = logging.FileHandler('Summary.log','w')
#ResultFormatter = logging.Formatter('%(asctime)s : %(levelname)s : %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')
ResultFormatter = logging.Formatter('%(message)s')
WResultLog.setFormatter(ResultFormatter)
ResultLog.setLevel(logging.DEBUG)
ResultScreen = logging.StreamHandler()
ResultScreen.setFormatter(ResultFormatter)
#ResultLog.addHandler(ResultScreen)
ResultLog.addHandler(WResultLog)

def DetectLinuxDistro():
    if os.path.isfile("/etc/redhat-release"):
        return (True, "RedHat")
    if os.path.isfile("/etc/lsb-release") and "Ubuntu" in GetFileContents("/etc/lsb-release"):
        return (True, "Ubuntu")
    if os.path.isfile("/etc/debian_version"):
        return (True, "Debian")
    if os.path.isfile("/etc/SuSE-release"):
        return (True, "Suse")
    return (False, "Unknown")

def IsUbuntu():
        cmd = "cat /etc/issue"
        tmp=Run(cmd)
        return ("Ubuntu" in tmp)

def Run(cmd):
        proc=subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        proc.wait()
        op = proc.stdout.read()
        RunLog.debug(op)
        code=proc.returncode
        int(code)
        #print code
        if code !=0:
            #RunLog.error(op)
            exception = 1
            #updateState('TestFailed')
        else:
            #RunLog.info(op)
            #print (op)
            return op
        if exception == 1:
            str_code = str(code)
            #RunLog.critical("Exception, return code is " + str_code + #" for command " + cmd)
            #return commands.getoutput(cmd)
            return op

def JustRun(cmd):
    return commands.getoutput(cmd)

def UpdateState(testState):
    stateFile = open('state.txt', 'w')
    stateFile.write(testState)
    stateFile.close()
    
def GetFileContents(filepath):
    file = None
    try:
        file = open(filepath)
    except:
        return None
    if file == None:
        return None
    try:
        return file.read()
    finally:
        file.close()


#-----------------------------------------------------------------------------------------------------------------------------------------------------

# iperf server

def GetServerCommand():
        import argparse
        import sys
                #for error checking
        validPlatformValues = ["532","540","541", "542", "550"]
        parser = argparse.ArgumentParser()

        parser.add_argument('-u', '--udp', help='switch : starts the server in udp data packets listening mode.', choices=['yes', 'no'] )
        parser.add_argument('-p', '--port', help='specifies which port should be used', required=True, type= int)
        parser.add_argument('-m', '--maxsegdisplay', help='Maximum Segment Size display ', choices=['yes', 'no'])
        parser.add_argument('-M', '--maxsegset', help='Maximum Segment Size Settings', type = int)
        parser.add_argument('-i', '--interval', help='specifies frequency of the output to be displyed on screen', type= int, required = True)
        args = parser.parse_args()
                #if no value specified then stop
        command = 'iperf -s' + ' -i' + str(args.interval) + ' -p' + str(args.port)
        if args.udp == 'yes':
                command = command + ' -u'
        if args.maxsegset != None:
                command = command + ' -M' + str(args.maxsegset)
        if args.maxsegdisplay == 'yes':
                command = command + ' -m'
	
	finalCommand = 'nohup ' + command + ' >  iperf-server.txt &'
        return finalCommand

#_________________________________________________________________________________________________________________________________________________

def StopServer():
	RunLog.info("Killing iperf server if running ..")
	temp = Run("killall iperf")
	
def StartServer(server):
    StopServer()
    RunLog.info("Starting iperf server..")
    temp = Run(server)
    tmp = Run("sleep 1")
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
                iperfPID = Run('pidof iperf')
                RunLog.info("Server started successfully. PID : %s", iperfPID)
                Run('echo "yes" > isServerStarted.txt')
		#UpdateState('TestCompleted')

    else :
        RunLog.error('Server Failed to start..')
        Run("echo yes > isServerStarted.txt")
        UpdateState('Aborted')

#_______________________________________________________________________________________________________________________________________________

def AnalyseClientUpdateResult():
        iperfstatus = open('iperf-client.txt', 'r')
        output = iperfstatus.read()
        #print output
        Failure = 0
        RunLog.info("Checking if client was connected to server..")
        if ("connected" in output) :
                if ("TestInComplete" in output):
                        RunLog.error('Client was successfully connected but, iperf process failed to exit.')
                        Failure = Failure + 1
                if("failed" in output):
                        RunLog.error("Client connected with some failed connections!")
                        Failure = Failure + 1
                if("error" in output):
                        RunLog.error("There were some errors in the connections.")
                        Failure = Failure + 1

                if("refused" in output):
                        RunLog.error("some connections were refused.")
                        Failure = Failure + 1

                if(Failure == 0):
                        RunLog.info("Client was successfully connected to server")
                        ResultLog.info("PASS")
                        UpdateState("TestCompleted")
                else:
                        ResultLog.info("FAIL")
                        UpdateState("TestCompleted")

        else:
		if("No address associated" in output):
                	RunLog.error('Client was not connected to server.')
	                RunLog.error("No address associated with hostname")
	                ResultLog.info('FAIL')
	                UpdateState("TestCompleted")

                elif("Connection refused" in output):
                        RunLog.error('Client was not connected to server.')
                        RunLog.error("Connection refused by the server.")
                        ResultLog.info('FAIL')
                        UpdateState("TestCompleted")



                elif("Name or service not known" in output):
                        RunLog.error('Client was not connected to server.')
                        RunLog.error("Name or service not known.")
                        ResultLog.info('FAIL')
                        UpdateState("TestCompleted")


		else:
                        RunLog.error('Client was not connected to server.')
                        RunLog.error("Unlisted error. Check logs for more information...!")
                        ResultLog.info('FAIL')
                        UpdateState("TestCompleted")


#________________________________________________________________________________________________________________________________________________

def isProcessRunning(processName):
        temp = 'ps -ef'
        outProcess = Run(temp)
        #print(iperfProcess)
        ProcessCount = outProcess.count('iperf -c')
        if (ProcessCount > 0):
                return "True"
        else:
                return "False"

#________________________________________________________________________________________________________________________________________________
#
#
# VNET Library..


#DECLARE GLOBAL VARIBALES HERE FIRST AND THEN ADD THEM TO SetVnetGlobalParametesrs()
lisvnetlab_db_filepath = ''
lisvnetlab_rev_filepath = ''
dns_server_ip = ''
resolv_conf_filepath = ''
hosts_filepath = ''
def SetVnetGlobalParameters():
    global dns_server_ip
    global lisvnetlab_db_filepath
    global lisvnetlab_rev_filepath
    global resolv_conf_filepath
    global hosts_filepath
    lisvnetlab_db_filepath =  '/etc/bind/zones/lisvnetlab.com.db'
    lisvnetlab_rev_filepath = '/etc/bind/zones/rev.4.168.192.in-addr.arpa'
    dns_server_ip = '192.168.3.120'
    resolv_conf_filepath = '/etc/resolv.conf'
    hosts_filepath = '/etc/hosts'

def GetFileContentsByLines(filepath):
    file = None
    try:
        file = open(filepath, 'r')
    except:
        return None
    if file == None:
        return None
    try:
        file_lines =  file.readlines()
        return file_lines
    finally:
        file.close()

def RemoveStringMatchLinesFromFile(filepath, matchString):
    try:
        old_file_lines = GetFileContentsByLines(filepath)
        NewFile =  open(filepath,'w')
        for eachLine in old_file_lines:
            if not matchString in eachLine :
                NewFile.writelines(eachLine)
#By the end of this for loop, Selected lines will be removed.
            else:
                print("removed %s from %s" % ( eachLine.replace('\n',''), filepath))
        NewFile.close()
    except:
        print ('File : %s not found.' % filepath)

def ReplaceStringMatchLinesFromFile(filepath, matchString, newLine):
    try:
        old_file_lines = GetFileContentsByLines(filepath)
        NewFile =  open(filepath,'w')
        for eachLine in old_file_lines:
            if matchString in eachLine :
                if '\n' in newLine:
                    NewFile.writelines(newLine)
                else :
                    NewFile.writelines('%s\n' % newLine)
            else :
                NewFile.writelines(eachLine)
        NewFile.close()
    except:
        print ('File : %s not found.' % filepath)

def GetStringMatchCount(filepath, matchString):
    #try:
        NewFile =  open(filepath,'r')
        NewFile.close()
        matchCount = 0
        file_lines = GetFileContentsByLines(filepath)
        for eachLine in file_lines:
            if matchString in eachLine :
                matchCount = matchCount + 1
        return matchCount
    #except:
        print ('File : %s not found.' % filepath)

def RemoveICAVMsFromDBfile():
    SetVnetGlobalParameters()    
    matchString = 'ICA-'
    RemoveStringMatchLinesFromFile(lisvnetlab_db_filepath,matchString)

def RemoveICAVMsFromREVfile():
    SetVnetGlobalParameters()
    matchString = 'ICA-'
    RemoveStringMatchLinesFromFile(lisvnetlab_rev_filepath,matchString)


def RetryOperation(operation, description, expectResult=None, maxRetryCount=18, retryInterval=10):
    retryCount = 1

    while True:
        RunLog.info("Attempt : %s : %s", retryCount, description)
        ret = None

        try:
            ret = Run(operation)
            if (expectResult and (ret.strip() == expectResult)) or (expectResult == None):
                return ret
        except:
            RunLog.info("Retrying Operation")

        if retryCount >= maxRetryCount:
            break
        retryCount += 1
        time.sleep(retryInterval)
    if(expectResult != None):
        return ret
    return None

def AppendTextToFile(filepath,textString):
    #THIS FUNCTION DONES NOT CREATES ANY FILE. THE FILE MUST PRESENT AT THE SPECIFIED LOCATION.
    try:
        fileToEdit = open ( filepath , 'r' )
        fileToEdit.close()
        fileToEdit = open ( filepath , 'a' )
        if not '\n' in textString:
            fileToEdit.write(textString)
        else:
            fileToEdit.writelines(textString)
        fileToEdit.close()
    except:
        print('File %s not found' % filepath)


def AddICAVMsToDnsServer(HostnameDIP):
    SetVnetGlobalParameters()
    #PARSE THE VM DETAILS FIRST.
    separatedVMs = HostnameDIP.split('^')
    for eachVM in separatedVMs:
        eachVMdata = eachVM.split(':')
        eachVMHostname = eachVMdata[0]
        eachVMDIP = eachVMdata[1]
        lastDigitofVMDIP = eachVMDIP.split('.')[3]
        lisvnetlabDBstring = '%s\tIN\tA\t%s\n' % (eachVMHostname,eachVMDIP)
        print(lisvnetlabDBstring.replace('\n',''))
        AppendTextToFile(lisvnetlab_db_filepath,lisvnetlabDBstring)
        lisvnetlabREVstring = '%s\tIN\tPTR\t%s.lisvnetlab.com.\n' % (lastDigitofVMDIP,eachVMHostname)
        AppendTextToFile(lisvnetlab_rev_filepath,lisvnetlabREVstring)
        print(lisvnetlabREVstring.replace('\n',''))

def RemoteUpload(hostIP, hostPassword, hostUsername, hostPort, filesToUpload, remoteLocation):
    import paramiko
#    print ('%s %s' % (hostIP,hostPort))
    transport = paramiko.Transport((hostIP,int(hostPort)))
    try:
        print('Connecting to %s'% hostIP),
        transport.connect(username = hostUsername, password = hostPassword)
        print('...Connected.')
        try:
            sftp = paramiko.SFTPClient.from_transport(transport)
            filesToUpload =  filesToUpload.split(',')
            for eachFile in filesToUpload :
                eachFileName = eachFile.split('/')
#                print eachFileName
                eachFileNameLength = len(eachFileName)
#                print eachFileNameLength
                exactFileName = eachFileName[eachFileNameLength-1]
#                print exactFileName
                if remoteLocation[-1] == '/':
                    newFile = "%s%s" % (remoteLocation,exactFileName)
                else:
                    newFile = "%s/%s" % (remoteLocation,exactFileName)
#                print ("%s - %s" % (eachFile, newFile))
                try:
                    print ("Uploading %s to %s" % (eachFile, newFile)),
                    sftp.put(eachFile, newFile)
                    print ('...OK!')
                except:
                    print('...Error!')
            transport.close()					
        except:    
            print("Failed to upload to %s" % hostIP)

    except:
        print("...Failed!")

def RemoteDownload(hostIP, hostPassword, hostUsername, hostPort, filesToDownload, localLocation):
    import paramiko
#    print ('%s %s' % (hostIP,hostPort))
    transport = paramiko.Transport((hostIP,int(hostPort)))
    try:
        print('Connecting to %s'% hostIP),
        transport.connect(username = hostUsername, password = hostPassword)
        print('...Connected.')
        try:
            sftp = paramiko.SFTPClient.from_transport(transport)
            filesToDownload =  filesToDownload.split(',')
            for eachFile in filesToDownload :
                eachFileName = eachFile.split('/')
#                print eachFileName
                eachFileNameLength = len(eachFileName)
#                print eachFileNameLength
                exactFileName = eachFileName[eachFileNameLength-1]
#                print exactFileName
                if localLocation[-1] == '/':
                    newFile = "%s%s" % (localLocation,exactFileName)
                else:
                    newFile = "%s/%s" % (localLocation,exactFileName)
#                print ("%s - %s" % (eachFile, newFile))
                try:
                    print ("Downloading %s to %s" % (eachFile, newFile)),
                    sftp.get(eachFile, newFile)
                    print ('...OK!')
                except:
                    print('...Error!')
            transport.close()
        except:
            print("Failed to Download to %s" % hostIP)

    except:
        print("...Failed!")


def ConfigureResolvConf():
    isDnsEntry =  GetStringMatchCount(resolv_conf_filepath,dns_server_ip)
    hostName = JustRun('hostname')
    if isDnsEntry == 1:
        ReplaceStringMatchLinesFromFile(resolv_conf_filepath,'search','search lisvnetlab.com')
        ConfigureHostsFile()
        isHostsEdited = GetStringMatchCount(hosts_filepath, hostName)
        isDnsEntry =  GetStringMatchCount(resolv_conf_filepath,dns_server_ip)
        isDnsNameEntry =  GetStringMatchCount(resolv_conf_filepath,'search lisvnetlab.com')
        if isDnsEntry == 1 and isDnsNameEntry == 1 and isHostsEdited >= 1:
            print "ExitCode : 0"
        else :
            print "ExitCode : 1"
    else:
        print('Dns server IP is not present in resolv.conf file')
        print "ExitCode : 2"

def ConfigureHostsFile():
    hostName = JustRun('hostname')
    AppendTextToFile(hosts_filepath,"127.0.0.1 %s\n" % hostName)
    
