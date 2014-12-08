#!/usr/bin/python
from azuremodules import *
import sys
import time
import re
import os
import linecache
import imp
import os.path

current_distro	= "unknown"
distro_version	= "unknown"
sudo_password	= "rdPa$$w0rd"

rpm_links = {}
tar_link = {}
current_distro = "unknown"
packages_list_xml = "./packages.xml"

def set_variables_OS_dependent():
	global current_distro
	global distro_version

	RunLog.info ("\nset_variables_OS_dependent ..")
	[current_distro, distro_version] = DetectDistro()
	if(current_distro == 'unknown'):
		RunLog.info ("unknown distribution found exitting")
		ResultLog.info('ABORTED')
		exit()

	RunLog.info ("\nset_variables_OS_dependent ..[done]")

def download_and_install_rpm(package):
	RunLog.info("Installing Package: " + package+" from rpmlink")
	if package in rpm_links:
		if DownloadUrl(rpm_links.get(package), "/tmp/"):
			if InstallRpm("/tmp/"+re.split("/",rpm_links.get(package))[-1], package):
				RunLog.info("Installing Package: " + package+" from rpmlink done!")
				return True

	RunLog.info("Installing Package: " + package+" from rpmlink failed!!")
	return False

def yum_package_install(package):
	if(YumPackageInstall(package) == True):
		return True
	elif(download_and_install_rpm(package) == True):
		return True
	else:
		return False

def zypper_package_install(package):
	if(ZypperPackageInstall(package) == True):
		return True
	elif(download_and_install_rpm(package) == True):
		return True
	else:
		return False

def install_waagent_from_github():
	RunLog.info ("Installing waagent from github...")

	DownloadUrl(tar_link.get("waagent"), "/tmp/")
	filename = tar_link.get("waagent").split('/')[-1]
	RunLog.info ("Waagent tar file name is: "+ filename+"|")

	if os.path.isfile("/tmp/"+filename):
		Run("tar -zxvf /tmp/"+filename+" -C /tmp >/tmp/tar.log")
		output = Run("tar -ztf /tmp/"+filename+" | head")
		folder_name = output.split('\n')[0]

		ExecMultiCmdsLocalSudo(["waagent -uninstall", \
		"chmod +x /tmp/"+folder_name+"waagent",\
		"cp /tmp/"+folder_name+"waagent /usr/sbin/", \
		"waagent -install", \
		"cp /tmp/"+folder_name+"config/waagent.conf  /etc/waagent.conf", \
		"rm -rf /tmp/"+folder_name])
		return True		
	else:
		RunLog.info ("Installing waagent from github...[failed]")

	return False

def install_package(package):
	RunLog.info ("\nInstall_package: "+package)
	if (package == "waagent"):
		return install_waagent_from_github()
	else:
		if ((current_distro == "ubuntu") or (current_distro == "Debian")):
			return AptgetPackageInstall(package)
		elif ((current_distro == "rhel") or (current_distro == "Oracle") or (current_distro == 'centos') or (current_distro == 'fedora')):
			return yum_package_install(package)
		elif (current_distro == "SUSE Linux") or (current_distro == "openSUSE"):
			return zypper_package_install(package)
		else:
			RunLog.info (package + ": package installation failed!")
			RunLog.info (current_distro + ": Unrecognised Distribution OS Linux found!")
			return False

def DownloadUrl(url, destination_folder):
    rtrn = Run("wget -P "+destination_folder+" "+url+ " 2>&1")

    if(rtrn.rfind("wget: command not found") != -1):
        install_package("wget")
        rtrn = Run("wget -P "+destination_folder+" "+url+ " 2>&1")

    if( rtrn.rfind("100%") != -1):
        return True
    else:
        RunLog.info (rtrn)
        return False
		
def ConfigFilesUpdate():
	firewall_disabled = False
	update_configuration = False

	RunLog.info("Updating configuration files..")

	# Disable 'requiretty' in sudoers
	Run("sed -r 's/^.*Defaults\s*requiretty.*$/#Defaults requiretty/g' /etc/sudoers -i")

	#Configuration of /etc/security/pam_env.conf
	Run("sed -i 's/^#REMOTEHOST/REMOTEHOST/g' /etc/security/pam_env.conf")
	Run("sed -i 's/^#DISPLAY/DISPLAY/g' /etc/security/pam_env.conf")
	pamconf = Run("cat /etc/security/pam_env.conf")

	if ((pamconf.find('#REMOTEHOST') == -1) and (pamconf.find('#DISPLAY') == -1)):
		RunLog.info("/etc/security/pam_env.conf\n")
		update_configuration = True
	else:
		RunLog.error('Config file not updated\n')
		update_configuration = False

	if (update_configuration == True):
		RunLog.info('Config file updation succesfully!\n')
		UpdateState("Config file updation succesfully!")
	else:
		RunLog.error('[Error] Config file updation failed!')
		UpdateState("Config file updation failed!")

	#Configuration of Firewall(Disable)
	if (current_distro == "ubuntu"):
		FirewallInfo = Run("ufw disable")
		if (FirewallInfo.find('Firewall stopped and disabled on system startup')):
			RunLog.info('**Firewall Stopped Successfully** \n')
			firewall_disabled = True
		else:
			RunLog.error('**Failed to disable Firewall**')
			firewall_disabled = False

	if ((current_distro == "SUSE Linux") or (current_distro == "openSUSE") or (current_distro == "sles")):
		FWBootInfo = Run("/sbin/yast2 firewall startup manual")
		if(FWBootInfo.find('Removing firewall from the boot process')):
			RunLog.info('Firewall Removed successfully from boot process \n')

		FirewallInfo = Run("/sbin/rcSuSEfirewall2 status")

		if (FirewallInfo.find('SuSEfirewall2') and FirewallInfo.find('unused')):
			RunLog.info('**Firewall Stopped Successfully** \n')
			firewall_disabled = True
		else:
			RunLog.error('**Failed to disable Firewall**')
			firewall_disabled = False
	
	if(firewall_disabled and update_configuration):
		return True
	else:
		return False

def deprovision():
	success = False
	# These commads will do deprovision and set the root password with out using any pexpect module.
	# Using openssl command to generate passwd hash and keeping it in /etc/shadow file.
	deprovision_commands = (
	"/usr/sbin/waagent -force -deprovision+user 2>&1", \
	"sudo_hash=$(openssl passwd -1 '"+sudo_password+"')", \
	"echo $sudo_hash",\
	"sed -i 's_\(^root:\)\(.*\)\(:.*:.*:.*:.*:.*:.*:.*.*\)_\\1'$sudo_hash'\\3_' /etc/shadow")

	output = ExecMultiCmdsLocalSudo(deprovision_commands)
	outputlist = re.split("\n", output)

	for line in outputlist:
		if (re.match(r'WARNING!.*account and entire home directory will be deleted', line, re.M|re.I)):
			RunLog.info ("'waagent -deprovision+user' command succesful\n")
			success = True
			break

	if (success == False):
		RunLog.info ("'waagent -deprovision+user' command failed\n")
	
	output = Run("ls /home/ |wc -l")
	if(not output.find("0")):
		RunLog.info ("'waagent -deprovision+user' command failed\nCould not delete '/home/test1/'")
		success = False

	return success

def RunTest():
	UpdateState("TestRunning")
	success = True

	try:
		import xml.etree.cElementTree as ET
	except ImportError:
		import xml.etree.ElementTree as ET

	# Parse the packages.xml file into memory
	packages_xml_file = ET.parse(packages_list_xml)
	xml_root = packages_xml_file.getroot()

	parse_success = False

	for branch in xml_root:
		for node in branch:
			if (node.tag == "packages"):
				if(current_distro == node.attrib["distro"]):
					packages_list = node.text.split(" ")
			elif node.tag == "waLinuxAgent_link":
				pass
			elif node.tag == "rpm_link":
				rpm_links[node.attrib["name"]] = node.text
			elif node.tag == "tar_link":
				tar_link[node.attrib["name"]] = node.text

	for package in packages_list:
		if(not install_package(package)):
			success == False
			break

	if success == True:
		ConfigFilesUpdate()
		deprovision()
		ResultLog.info('PASS')
	else:
		ResultLog.info('FAIL')

#Code execution starts from here
if not os.path.isfile("packages.xml"):
	RunLog.info("'packages.xml' file is missing\n")
	exit ()

set_variables_OS_dependent()
UpdateRepos(current_distro)

RunTest()
Run("mkdir logs;cp -rf ~/* /tmp/logs")
