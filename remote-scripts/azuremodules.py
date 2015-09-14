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

def UpdateRepos(current_distro):
	RunLog.info ("\nUpdating the repositoriy information...")
	if ((current_distro == "ubuntu") or (current_distro == "Debian")):
		Run("apt-get update")
	elif ((current_distro == "rhel") or (current_distro == "Oracle") or (current_distro == 'centos')):
		RunYumUpdate("yum -y update")
	elif (current_distro == "opensuse") or (current_distro == "SUSE") or (current_distro == "sles"):
		Run("zypper --non-interactive --gpg-auto-import-keys update")
	else:
		RunLog.info("Repo upgradation failed on:"+current_distro)
		return False

	RunLog.info ("Updating the repositoriy information... [done]")
	return True

def DownloadUrl(url, destination_folder, output_file=None):
    cmd = "wget -P "+destination_folder+" "+url+ " 2>&1"
    if output_file is not None:
        cmd = "wget {0} -O {1} 2>&1".format(url, output_file)
        
    rtrn = Run(cmd)

    if(rtrn.rfind("wget: command not found") != -1):
        InstallPackage("wget")
        rtrn = Run(cmd)

    if( rtrn.rfind("100%") != -1):
        return True
    else:
        RunLog.info (rtrn)
        return False

def DetectDistro():
	distribution = 'unknown'
	version = 'unknown'
	
	RunLog.info("Detecting Distro ")
	output = Run("cat /etc/*-release")
	outputlist = re.split("\n", output)
	
	for line in outputlist:
		line = re.sub('"', '', line)
		if (re.match(r'^ID=(.*)',line,re.M|re.I) ):
			matchObj = re.match( r'^ID=(.*)', line, re.M|re.I)
			distribution  = matchObj.group(1)
		elif (re.match(r'^VERSION_ID=(.*)',line,re.M|re.I) ):
			matchObj = re.match( r'^VERSION_ID=(.*)', line, re.M|re.I)
			version = matchObj.group(1)

	if(distribution == "ol"):
		distribution = 'Oracle'
		
	if(distribution == 'unknown'):
		# Finding the Distro
		for line in outputlist:
			if (re.match(r'.*Ubuntu.*',line,re.M|re.I) ):
				distribution = 'ubuntu'
				break
			elif (re.match(r'.*SUSE Linux.*',line,re.M|re.I)):
				distribution = 'SUSE'
				break
			elif (re.match(r'.*openSUSE.*',line,re.M|re.I)):
				distribution = 'opensuse'
				break
			elif (re.match(r'.*centos.*',line,re.M|re.I)):
				distribution = 'centos'
				break
			elif (re.match(r'.*Oracle.*',line,re.M|re.I)):
				distribution = 'Oracle'
				break
			elif (re.match(r'.*Red Hat.*',line,re.M|re.I)):
				distribution = 'rhel'
				break
			elif (re.match(r'.*Fedora.*',line,re.M|re.I)):
				distribution = 'fedora'
				break					
	return [distribution, version]

def FileGetContents(filename):
    with open(filename) as f:
        return f.read()

def ExecMultiCmdsLocalSudo(cmd_list):
	f = open('/tmp/temp_script.sh','w')
	for line in cmd_list:
			f.write(line+'\n')
	f.close()
	Run ("chmod +x /tmp/temp_script.sh")
	Run ("/tmp/temp_script.sh 2>&1 > /tmp/exec_multi_cmds_local_sudo.log")
	return FileGetContents("/tmp/exec_multi_cmds_local_sudo.log")

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

def RunYumUpdate(cmd):
        proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        retval = proc.communicate()
        op = retval[0]
        RunLog.debug(op)
        code = proc.returncode
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
# Instlaltion routines
		
def YumPackageInstall(package):
	RunLog.info(("\nyum_package_install: " + package))
	output = Run("yum install -y "+package)
	outputlist = re.split("\n", output)

	for line in outputlist:
		#Package installed successfully
		if (re.match(r'Complete!', line, re.M|re.I)):
			RunLog.info((package+": package installed successfully.\n"+line))
			return True
		#package is already installed
		elif (re.match(r'.* already installed and latest version', line, re.M|re.I)):
			RunLog.info((package + ": package is already installed.\n"+line))
			return True
		elif (re.match(r'^Nothing to do', line, re.M|re.I)):
			RunLog.info((package + ": package already installed.\n"+line))
			return True
		#Package installation failed
		elif (re.match(r'^Error: Nothing to do', line, re.M|re.I)):
			break
		#package is not found on the repository
		elif (re.match(r'^No package '+ re.escape(package)+ r' available', line, re.M|re.I)):
			break
			
	#Consider package installation failed if non of the above matches.
	RunLog.error((package + ": package installation failed!\n" +output))
	return False

def AptgetPackageInstall(package,dbpasswd = "root"):
	RunLog.info("Installing Package: " + package)
	# Identify the package for Ubuntu
	# We Haven't installed mysql-secure_installation for Ubuntu Distro
	if (package == 'mysql-server'):
		RunLog.info( "apt-get function package:" + package) 		
		cmds = ("export DEBIAN_FRONTEND=noninteractive","echo mysql-server mysql-server/root_password select " + dbpasswd + " | debconf-set-selections", "echo mysql-server mysql-server/root_password_again select " + dbpasswd  + "| debconf-set-selections", "apt-get install -y  --force-yes mysql-server")
		output = ExecMultiCmdsLocalSudo(cmds)
	else:
		output = Run("apt-get install -y  --force-yes "+package)
	
	outputlist = re.split("\n", output)	
 
	unpacking = False
	setting_up = False

	for line in outputlist:
		#package is already installed
		if (re.match(re.escape(package) + r' is already the newest version', line, re.M|re.I)):
			RunLog.info(package + ": package is already installed."+line)
			return True
		#package installation check 1	
		elif (re.match(r'Unpacking '+ re.escape(package) + r" \(.*" , line, re.M|re.I)):
			unpacking = True
		#package installation check 2
		elif (re.match(r'Setting up '+ re.escape(package) + r" \(.*" , line, re.M|re.I)):
			setting_up = True
		#Package installed successfully
		if (setting_up and unpacking):
			RunLog.info(package+": package installed successfully.")
			return True
		#package is not found on the repository
		elif (re.match(r'E: Unable to locate package '+ re.escape(package), line, re.M|re.I)):
			break
		#package installation failed due to server unavailability
		elif (re.match(r'E: Unable to fetch some archives', line, re.M|re.I)):
			break
		
	#Consider package installation failed if non of the above matches.
	RunLog.info(package + ": package installation failed!\n")
	RunLog.info("Error log: "+output)
	return False

def ZypperPackageInstall(package):
	RunLog.info( "\nzypper_package_install: " + package)

	output = Run("zypper --non-interactive in "+package)
	outputlist = re.split("\n", output)
		
	for line in outputlist:
		#Package installed successfully
		if (re.match(r'.*Installing: '+re.escape(package)+r'.*done', line, re.M|re.I)):
			RunLog.info((package+": package installed successfully.\n"+line))
			return True
		#package is already installed
		elif (re.match(r'\''+re.escape(package)+r'\' is already installed', line, re.M|re.I)):
			RunLog.info((package + ": package is already installed.\n"+line))
			return True
		#package is not found on the repository
		elif (re.match(r'^No provider of \''+ re.escape(package) + r'\' found', line, re.M|re.I)):
			break

	#Consider package installation failed if non of the above matches.
	RunLog.error((package + ": package installation failed!\n"+output))
	return False

def ZypperPackageRemove(package):
	RunLog.info( "\nzypper_package_remove: " + package)

	output = Run("zypper --non-interactive remove "+package)
	outputlist = re.split("\n", output)
		
	for line in outputlist:
		#Package removed successfully
		if (re.match(r'.*Removing '+re.escape(package)+r'.*done', line, re.M|re.I)):
			RunLog.info((package+": package removed successfully.\n"+line))
			return True
		#package is not installed
		elif (re.match(r'\''+re.escape(package)+r'\' is not installed', line, re.M|re.I)):
			RunLog.info((package + ": package is not installed.\n"+line))
			return True
		#package is not found on the repository
		elif (re.match(r'\''+re.escape(package)+r'\' not found in package names', line, re.M|re.I)):
			return True

	#Consider package remove failed if non of the above matches.
	RunLog.error((package + ": package remove failed!\n"+output))
	return False
	
def InstallPackage(package):
	RunLog.info( "\nInstall_package: "+package)
	[current_distro, distro_version] = DetectDistro()
	if ((current_distro == "ubuntu") or (current_distro == "Debian")):
		return AptgetPackageInstall(package)
	elif ((current_distro == "rhel") or (current_distro == "Oracle") or (current_distro == 'centos') or (current_distro == 'fedora')):
		return YumPackageInstall(package)
	elif ((current_distro == "SUSE") or (current_distro == "opensuse") or (current_distro == "sles")):
		return ZypperPackageInstall(package)
	else:
		RunLog.error((package + ": package installation failed!"))
		RunLog.info((current_distro + ": Unrecognised Distribution OS Linux found!"))
		return False

def InstallDeb(file_path):
	RunLog.info( "\nInstalling package: "+file_path)
	output = Run("dpkg -i "+file_path+" 2>&1")
	RunLog.info(output)
	outputlist = re.split("\n", output)

	for line in outputlist:
		#package is already installed
		if(re.match("installation successfully completed", line, re.M|re.I)):
			RunLog.info(file_path + ": package installed successfully."+line)
			return True			
			
	RunLog.info(file_path+": Installation failed"+output)
	return False

def InstallRpm(file_path, package_name):
	RunLog.info( "\nInstalling package: "+file_path)
	output = Run("rpm -ivh --nodeps "+file_path+" 2>&1")
	RunLog.info(output)
	outputlist = re.split("\n", output)
	package = re.split("/", file_path )[-1]
	matchObj = re.match( r'(.*?)\.rpm', package, re.M|re.I)
	package = matchObj.group(1)
	
	for line in outputlist:
		#package is already installed
		if (re.match(r'.*package'+re.escape(package) + r'.*is already installed', line, re.M|re.I)):
			RunLog.info(file_path + ": package is already installed."+line)
			return True
		elif(re.match(re.escape(package) + r'.*######', line, re.M|re.I)):
			RunLog.info(package + ": package installed successfully."+line)
			return True
		elif(re.match(re.escape(package_name) + r'.*######', line, re.M|re.I)): 
			RunLog.info(package + ": package installed successfully."+line) 
			return True 
			
	RunLog.info(file_path+": Installation failed"+output)
	return False

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

def GetOSDisk():
    if(IsUbuntu()):
        resourceDiskPartition = JustRun("grep -i '/mnt' /etc/mtab | awk '{print $1;}' | tr -d '\n'")
    else:
        resourceDiskPartition = JustRun("grep -i '/mnt/resource' /etc/mtab | awk '{print $1;}' | tr -d '\n'")
    if 'sda' in resourceDiskPartition:
        return 'sdb'
    else :
        return 'sda'
