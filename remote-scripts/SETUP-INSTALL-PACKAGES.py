#!/usr/bin/python
from azuremodules import *
import sys
import time
import re
import os
import linecache
import imp
import os.path

#user_name = "test1"
#sudo_password = 'rdPa$$w0rd'
user_name = "test"
sudo_password = 'Redhat.Redhat.777'

#name of the packages xml file with complete path
rpm_links = {}
tar_link = {}
current_distro = "unknown"
packages_list_xml = "./packages.xml"

def file_get_contents(filename):
    with open(filename) as f:
        return f.read()

def set_variables_OS_dependent():
	RunLog.info ("\nset_variables_OS_dependent ..")
	global current_distro

	current_distro = detect_distro()

def install_rpm(file_path,package):
    RunLog.info (file_path)
    output = Run("echo '"+sudo_password+"' | sudo -S rpm -ivh "+file_path+" 2>&1")
    RunLog.info (output)
    outputlist = re.split("\n", output)

    for line in outputlist:
        #package is already installed
        if (re.match(r'.*'+re.escape(package) + r'.*is already installed', line, re.M|re.I)):
            RunLog.info(package + ": package is already installed."+line)
            return True
        elif(re.match(re.escape(package) + r'.*######', line, re.M|re.I)):
            RunLog.info(package + ": package installed successfully."+line)
            return True
            
    RunLog.info(file_path+": Installation failed"+output)
    return False

def yum_package_install(package):
    RunLog.info("Installing Package: " + package)
    output = Run("echo '"+sudo_password+"' | sudo -S yum install -y "+package+" 2>&1")
    outputlist = re.split("\n", output)

    for line in outputlist:
        #Package installed successfully
        if (re.match(r'Complete!', line, re.M|re.I)):
            RunLog.info(package+": package installed successfully.\n"+line)
            return True
        #package is already installed
        elif (re.match(r'.* already installed and latest version', line, re.M|re.I)):
            RunLog.info(package + ": package is already installed.\n"+line)
            return True
        elif (re.match(r'^Nothing to do', line, re.M|re.I)):
            RunLog.info(package + ": package already installed.\n"+line)
            return True
        #Package installation failed
        elif (re.match(r'^Error: Nothing to do', line, re.M|re.I)):
            break
        #package is not found on the reposotiry
        elif (re.match(r'^No package '+ re.escape(package)+ r' available', line, re.M|re.I)):
            break

    if package in rpm_links:
        if download_url(rpm_links.get(package), "/tmp/"):
            if install_rpm("/tmp/"+re.split("/",rpm_links.get(package))[-1],package):
                return True

    #Consider package installation failed if non of the above matches.
    RunLog.info(package + ": package installation failed!\n")
    RunLog.info("Error log: "+output)
    return False

def aptget_package_install(package):
    RunLog.info("Installing Package: " + package)
    output = Run("echo '"+sudo_password+"' | sudo -S apt-get install -y "+package+" 2>&1")
    outputlist = re.split("\n", output)

    unpacking = False
    setting_up = False

    for line in outputlist:
        #package is already installed
        if (re.match(re.escape(package) + r' is already the newest version', line, re.M|re.I)):
            RunLog.info(package + ": package is already installed."+line)
            return True
        #package installation check 1    
        elif (re.match(r'Unpacking '+ re.escape(package) + r" \(from.*" , line, re.M|re.I)):
            unpacking = True
        #package installation check 2
        elif (re.match(r'Setting up '+ re.escape(package) + r" \(.*" , line, re.M|re.I)):
            setting_up = True
        #Package installed successfully
        if (setting_up and unpacking):
            RunLog.info(package+": package installed successfully.")
            return True
        #package is not found on the reposotiry
        elif (re.match(r'E: Unable to locate package '+ re.escape(package), line, re.M|re.I)):
            break
        #package installation failed due to server unavailability
        elif (re.match(r'E: Unable to fetch some archives', line, re.M|re.I)):
            break

    #Consider package installation failed if non of the above matches.
    RunLog.info(package + ": package installation failed!\n")
    RunLog.info("Error log: "+output)
    return False

def zypper_package_install(package):
    RunLog.info("Installing Package: " + package)
    output = Run("echo '"+sudo_password+"' | sudo -S zypper  --non-interactive in "+package+" 2>&1")
    #output = Run("cat temp/log.txt")
    outputlist = re.split("\n", output)

    for line in outputlist:
            #Package installed successfully
            if (re.match(r'.*Installing: '+re.escape(package)+r'.*done', line, re.M|re.I)):
                    RunLog.info(package+": package installed successfully.\n"+line)
                    return True
            #package is already installed
            elif (re.match(r'\''+re.escape(package)+r'\' is already installed', line, re.M|re.I)):
                    RunLog.info(package + ": package is already installed.\n"+line)
                    return True
            #package is not found on the reposotiry
            elif (re.match(r'^No provider of \''+ re.escape(package) + r'\' found', line, re.M|re.I)):
                    break
    RunLog.info("Installing Package: " + package+" from rpmlink")
    if package in rpm_links:
        if download_url(rpm_links.get(package), "/tmp/"):
            if install_rpm("/tmp/"+re.split("/",rpm_links.get(package))[-1]):
                return True

    #Consider package installation failed if non of the above matches.
    RunLog.info(package + ": package installation failed!\n")
    RunLog.info("Error log: "+output)
    return False
	
def test_internet():
	ping_success = False

	output = Run("ping -c 3 google.com")
	outputlist = re.split("\n", output)
		
	for line in outputlist:
		if (re.match(r'.*icmp_seq=.*ttl=.*time=.*', line, re.M|re.I)):
			ping_success = True
			break

	if ping_success:
		RunLog.info ("Ping succeeded to google.com.")
		RunLog.info ("This Machine has internet connectivity.")
	else:
		RunLog.info ("Ping failed to google.com.")
		RunLog.info ("This Machine does not have internet connectivity.")
		RunLog.info (output)

	return ping_success

def install_waagent_from_github():
	RunLog.info ("Installing waagent from github...")
		
	download_url(tar_link.get("waagent"), "/tmp/")
	filename = tar_link.get("waagent").split('/')[-1]
	RunLog.info ("Waagent tar file name is: "+ filename+"|")
	
	if os.path.isfile("/tmp/"+filename):
		Run("tar -zxvf /tmp/"+filename+" -C /tmp >/tmp/tar.log")
		output = Run("tar -ztf /tmp/"+filename+" | head")
		folder_name = output.split('\n')[0]
		
		exec_multi_cmds_local_sudo(["waagent -uninstall", \
		"chmod +x /tmp/"+folder_name+"waagent",\
		"cp /tmp/"+folder_name+"waagent /usr/sbin/", \
		"waagent -install", \
		"cp /tmp/"+folder_name+"config/waagent.conf  /etc/waagent.conf", \
		"rm -rf /tmp/"+folder_name])
		return True		
	else:
		RunLog.info ("Installing waagent from github...[failed]")
	
	return False

def install_waagent_from_github_old():
	RunLog.info ("Installing waagent from github...")
	output = Run("waagent -version 2>&1")
	if ("WALinuxAgent-2.0.3" in output):
		RunLog.info ( "waagent version is already...[done]")
		RunLog.info ( "Installing waagent from github...[done]")
		return True
			
	download_url(tar_link.get("waagent"), "/tmp/")
	if os.path.isfile("/tmp/WALinuxAgent-2.0.3.tar.gz"):
		Run("tar -xvf  /tmp/WALinuxAgent-2.0.3.tar.gz  -C /tmp")
		exec_multi_cmds_local_sudo(["waagent -uninstall", \
		"chmod +x /tmp/WALinuxAgent-WALinuxAgent-2.0.3/waagent",\
		"cp /tmp/WALinuxAgent-WALinuxAgent-2.0.3/waagent /usr/sbin/", \
		"waagent -install", \
		"cp /tmp/WALinuxAgent-WALinuxAgent-2.0.3/config/waagent.conf  /etc/waagent.conf", \
		"rm -rf /tmp/WALinuxAgent-WALinuxAgent-2.0.3/"])
		
		output = Run("waagent -version 2>&1")
		if ("WALinuxAgent-2.0.3" in output):
			RunLog.info ( "Installing waagent from github...[done]")
			return True
	RunLog.info ("Installing waagent from github...[failed]")
	return False

def install_waagent_from_github_new():
	RunLog.info ("Installing waagent from github...")
	output = Run("waagent -version 2>&1")
			
	download_url(tar_link.get("waagent"), "/tmp/")
	if os.path.isfile("/tmp/waagent"):
		exec_multi_cmds_local_sudo([
		"chmod +x /tmp/waagent",\
		"cp /tmp/waagent /usr/sbin/", \
		"/usr/sbin/waagent -install"])
		return True
		
	return False
		
def install_package(package):
	RunLog.info ("\nInstall_package: "+package)
	if (package == "waagent"):
		return install_waagent_from_github()
	else:
		if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
			return aptget_package_install(package)
		elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
			return yum_package_install(package)
		elif (current_distro == "SUSE Linux") or (current_distro == "openSUSE"):
			return zypper_package_install(package)
		else:
			RunLog.info (package + ": package installation failed!")
			RunLog.info (current_distro + ": Unrecognised Distribution OS Linux found!")
			return False

def download_url(url, destination_folder):
    rtrn = Run("wget -P "+destination_folder+" "+url+ " 2>&1")

    if(rtrn.rfind("wget: command not found") != -1):
        install_package("wget")
        rtrn = Run("wget -P "+destination_folder+" "+url+ " 2>&1")

    if( rtrn.rfind("100%") != -1):
        return True
    else:
        RunLog.info (rtrn)
        return False
        
def update_repos():
    RunLog.info ("\nUpdating the repositoriy information...")
    if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
        Run("echo '"+sudo_password+"' | sudo -S apt-get update")
    elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
        Run("echo '"+sudo_password+"' | sudo -S yum -y update")
    elif (current_distro == "openSUSE") or (current_distro == "SUSE Linux"):
        Run("echo '"+sudo_password+"' | sudo -S zypper --non-interactive --gpg-auto-import-keys update")
    else:
        RunLog.info("Repo upgradation failed on:"+current_distro)
        exit
    RunLog.info ("Updating the repositoriy information... [done]")

def detect_distro():
    output = Run("echo '"+sudo_password+"' | sudo -S cat /etc/*-release")
    outputlist = re.split("\n", output)
    
    # Finding the distribution of the Linux 
    for line in outputlist:
        if (re.match(r'.*Ubuntu.*', line, re.M|re.I) ):
            return 'Ubuntu'
        elif (re.match(r'.*SUSE Linux.*', line, re.M|re.I)):
            return 'SUSE Linux'
        elif (re.match(r'.*openSUSE.*', line, re.M|re.I)):
            return 'openSUSE'
        elif (re.match(r'.*CentOS.*', line, re.M|re.I)):
            return 'CentOS'
        elif (re.match(r'.*Oracle.*', line, re.M|re.I)):
            return 'Oracle'

    return "unknown"

def ConfigFilesUpdate():
    return_status = True
    UpdateState("Config files upadating..")
    RunLog.info("Checking Config File updated or not")
#Configuration of /etc/security/pam_env.conf
    Run(" echo '"+sudo_password+"' | sudo -S  sed -i 's/^#REMOTEHOST/REMOTEHOST/g' /etc/security/pam_env.conf")
    Run(" echo '"+sudo_password+"' | sudo -S  sed -i 's/^#DISPLAY/DISPLAY/g' /etc/security/pam_env.conf")
    pamconf = Run(" echo '"+sudo_password+"' | sudo -S cat /etc/security/pam_env.conf")
    SuSEfirewall2 = Run(" echo '"+sudo_password+"' | sudo -S zypper --non-interactive install SuSEfirewall2 ")
    #RunLog.info "paminfo: ", pamconf
    if ( pamconf.find('#REMOTEHOST') == -1 and pamconf.find('#DISPLAY')== -1):
            RunLog.info('**successfully uncommented required two lines REMOTEHOST and DISPLAY ** \n')
            UpdateState("Config file updation Completed")

    else :
            RunLog.error('**Config file not updated **')
            UpdateState("Config file updation not Completed")
            return_status =  False

#Configuration of Firewall(Disable)
    #FWBootInfo = Run(" echo '"+sudo_password+"' | sudo -S  /sbin/yast2 firewall startup manual")
    #RunLog.info "FWBInfo: ",FWBootInfo
    #if(FWBootInfo.find('Removing firewall from the boot process')):
    #        RunLog.info('**Firewall Removed successfully from boot process ** \n')
    FirewallInfo = Run(" echo '"+sudo_password+"' | sudo -S  /sbin/rcSuSEfirewall2 status")

    if ( FirewallInfo.find('SuSEfirewall2') and FirewallInfo.find('unused')):
            RunLog.info('**Firewall Stopped Successfully** \n')
            UpdateState("Config file updation Completed")

    else :
            RunLog.error('**Firewall not disabled  **')
            UpdateState("Firewall Config file updation not Completed")
            return_status =  False
            
    return return_status

def exec_multi_cmds_local_sudo(cmd_list):
	f = open('/tmp/temp_script.sh','w')
	f.write("export PATH=$PATH:/sbin:/usr/sbin"+'\n') 
	for line in cmd_list:
		f.write(line+'\n') 
	f.close()
	Run ("chmod +x /tmp/temp_script.sh")
	Run ("echo '"+sudo_password+"' | sudo -S /tmp/temp_script.sh 2>&1 > /tmp/exec_multi_cmds_local_sudo.log")
	output = file_get_contents("/tmp/exec_multi_cmds_local_sudo.log")
	Run ("echo '"+sudo_password+"' | sudo -S rm -rf /tmp/exec_multi_cmds_local_sudo.log")
	Run ("echo '"+sudo_password+"' | sudo -S rm -rf /tmp/temp_script.sh")
	return output

def deprovision():
	success = False
	# These commads will do deprovision and set the root password with out using any pexpect module.
	# Using openssl command to generate passwd hash and keeping it in /etc/shadow file.
	deprovision_commands = (
	"/usr/sbin/waagent -force -deprovision+user 2>&1", \
	"sudo_hash=$(openssl passwd -1 '"+sudo_password+"')", \
	"echo $sudo_hash",\
	"sed -i 's_\(^root:\)\(.*\)\(:.*:.*:.*:.*:.*:.*:.*.*\)_\\1'$sudo_hash'\\3_' /etc/shadow")

	output = exec_multi_cmds_local_sudo(deprovision_commands)
	outputlist = re.split("\n", output)

	for line in outputlist:
		if (re.match(r'WARNING!.*account and entire home directory will be deleted', line, re.M|re.I)):
			#RunLog.info ("'waagent -deprovision+user' command succesful\n")
			print "waagent -deprovision+user command succesful"
			success = True

	if (success == False):
		#RunLog.info ("'waagent -deprovision+user' command failed\n")
		print("waagent -deprovision+user' command failed")

	#RunLog.info (output)
    #print ("this  is the output "+ output)
	if(os.path.isdir("/home/"+user_name)):
		#RunLog.info ("'waagent -deprovision+user' command failed\nCould not delete '/home/test1/'")
		print ("'waagent -deprovision+user' command failed\nCould not delete '/home/test1/'")
		success = False

	return success

def RunTest():
    UpdateState("TestRunning")
    global current_distro
    current_distro = detect_distro()
    success = True
    test_internet()
#    if (not test_internet()):
#		print "Aborting test as this VM doesn't have internet connectivity."
#		exit()

    #Reading packages names from "packages.xml" file
    output = Run("cat "+packages_list_xml)
    outputlist = re.split("\n", output)
    packages_list = []
    for line in outputlist:
        if "</packages>" in line:
            matchObj = re.match( r'<packages>(.*)</packages>', line, re.M|re.I)
            packages_list = str.split( matchObj.group(1))
            
        elif "</rpm_link>" in line:
            matchObj = re.match( r'<rpm_link = "(.*)">(.*)</rpm_link>', line, re.M|re.I)
            rpm_links[matchObj.group(1)] = matchObj.group(2)
			
        elif "</tar_link>" in line:
            matchObj = re.match( r'<tar_link = "(.*)">(.*)</tar_link>', line, re.M|re.I)
            tar_link[matchObj.group(1)] = matchObj.group(2)

    #Dtecting the linux distribution
    distro = DetectLinuxDistro()
    if (distro[0]):
        for package in packages_list:
            if(install_package(package)):
                RunLog.info( package+" on "+ distro[1]+ " successful")
            else:
                RunLog.info( package+" on "+ distro[1]+ " failed!")
                success = False
                
    success = ConfigFilesUpdate()
    success = deprovision()
    if success == True:
        ResultLog.info('PASS')
    else:
        ResultLog.info('FAIL')
              
    #UpdateState("TestCompleted")

#Code execution starts from here
if not os.path.isfile("packages.xml"):
	RunLog.info("'packages.xml' file is missing\n")
	exit ()

set_variables_OS_dependent()
update_repos()

RunTest()
Run("mkdir logs;cp -rf ~/* /tmp/logs")
