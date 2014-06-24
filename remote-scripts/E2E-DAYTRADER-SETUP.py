#!/usr/bin/python

import re
import imp
import sys
from azuremodules import *


daytrader_db_root_password = "root"
daytrader_db_name	= "tradedb"
daytrader_db_hostname = "localhost" 
daytrader_db_username = "trade"
daytrader_db_password = "trade"

vm_username		= "unknown"
vm_password		= "unknown"

front_endVM_ips = "unknown"

#OS dependent variables
pexpect_pkg_name        = "unknown"
current_distro          = "unknown"
service_httpd_name      = "unknown"
service_mysqld_name		= "unknown"
startup_file			= "/etc/rc.local"

def file_get_contents(filename):
    with open(filename) as f:
        return f.read()

def detect_distro():
	output = Run("echo '"+vm_password+"' | sudo -S cat /etc/*-release")
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
	
			
def set_variables_OS_dependent():
	RunLog.info( "\nset_variables_OS_dependent ..")
	global current_distro
	global pexpect_pkg_name
	global service_httpd_name
	global service_mysqld_name
	global startup_file

	current_distro = detect_distro()
	# Identify the Distro to Set OS Dependent Variables
	if ((current_distro == "Oracle") or (current_distro == "CentOS")):
		pexpect_pkg_name        = "pexpect"
		service_httpd_name      = "httpd"
		service_mysqld_name 	= "mysqld"
	elif (current_distro == "Ubuntu"):
		pexpect_pkg_name        = "python-pexpect"
		service_httpd_name      = "apache2"
		service_mysqld_name		= "mysql"
	elif ((current_distro == "openSUSE") or (current_distro == "SUSE Linux")):
		pexpect_pkg_name        = "python-pexpect"                     #check package name for suse
		service_httpd_name      = "apache2"
		service_mysqld_name		= "mysql"
		startup_file			= "/etc/init.d/boot.local"
	RunLog.info( "set_variables_OS_dependent .. [done]")

def update_repos():
	RunLog.info( "\nUpdating the repositoriy information...")
	if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
		Run("echo '"+vm_password+"' | sudo -S apt-get update")
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
		Run("echo '"+vm_password+"' | sudo -S yum -y update")
	elif (current_distro == "openSUSE") or (current_distro == "SUSE Linux"):
		Run("echo '"+vm_password+"' | sudo -S zypper --non-interactive --gpg-auto-import-keys update")
	else:
		RunLog.error(("Repo upgradation failed on:"+current_distro))
		#exit ()
	RunLog.info( "Updating the repositoriy information... [done]")

def disable_selinux():
	RunLog.info( "\nDiasabling selinux")
	selinuxinfo =  Run ("echo '"+vm_password+"' | sudo -S cat /etc/selinux/config")
	if (selinuxinfo.rfind('SELINUX=disabled') != -1):
		RunLog.info( "selinux is already disabled")
	else :
		selinux = Run ("echo '"+vm_password+"' | sudo -S sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config ")
		if (selinuxinfo.rfind('SELINUX=disabled') != -1):
			RunLog.info( "selinux is disabled")
	RunLog.info( "Diasabling selinux... [done]")

def disable_iptables():
	RunLog.info( "\n Disabling ip-tables..")
	if (current_distro == 'Ubuntu'):
		ufw = Run ("echo '"+vm_password+"' | sudo -S ufw disable")
		print ufw
	else:
		Run ("echo '"+vm_password+"' | sudo -S chkconfig iptables off")
		Run ("echo '"+vm_password+"' | sudo -S chkconfig ip6tables off")
		RunLog.info( "Diasabling iptables..[done]")

def yum_package_install(package):
	RunLog.info(("\nyum_package_install: " + package))
	output = Run("echo '"+vm_password+"' | sudo -S yum install -y "+package)
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

def aptget_package_install(package):
	
	RunLog.info("Installing Package: " + package)
	# Identify the package for Ubuntu	
	# We Haven't installed mysql-secure_installation for Ubuntu Distro
	if (package == 'mysql-server'):
		RunLog.info( "apt-get function package:" + package)
		
		cmds = ("export DEBIAN_FRONTEND=noninteractive","echo mysql-server mysql-server/root_password select " + daytrader_db_root_password + " | debconf-set-selections", "echo mysql-server mysql-server/root_password_again select " + daytrader_db_root_password  + "| debconf-set-selections", "echo '"+vm_password+"' | sudo -S apt-get install -y  --force-yes mysql-server")
		output = exec_multi_cmds_local_sudo(cmds)

	else:
		output = Run("echo '"+vm_password+"' | sudo -S apt-get install -y  --force-yes "+package)
	
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

def zypper_package_install(package):
	RunLog.info( "\nzypper_package_install: " + package)

	output = Run("echo '"+vm_password+"' | sudo -S zypper --non-interactive in "+package)
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

def install_deb(file_path):
	RunLog.info( "\nInstalling package: "+file_path)
	output = Run("echo '"+vm_password+"' | sudo -S  dpkg -i "+file_path+" 2>&1")
	RunLog.info( output)
	outputlist = re.split("\n", output)

	for line in outputlist:
		#package is already installed
		if(re.match("installation successfully completed", line, re.M|re.I)):
			RunLog.info(file_path + ": package installed successfully."+line)
			return True			
			
	RunLog.info(file_path+": Installation failed"+output)
	return False

def install_rpm(file_path):
	RunLog.info( "\nInstalling package: "+file_path)
	output = Run("echo '"+vm_password+"' | sudo -S rpm -ivh "+file_path+" 2>&1")
	RunLog.info( output)
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
			
	RunLog.info(file_path+": Installation failed"+output)
	return False
		
#needed to be generic
def yum_package_uninstall(package):
	RunLog.info( "\nRemoving package: "+package)
	output = Run ("echo '"+vm_password+"' | sudo -S yum remove -y "+package)
	return True

def zypper_package_uninstall(package):
	RunLog.info( "\nRemoving package: "+package)
	output = Run ("echo '"+vm_password+"' | sudo -S zypper remove -y "+package)
	return True
	
def aptget_package_uninstall(package):
	RunLog.info( "\nRemoving package: "+package)
	#output = Run ("echo '"+vm_password+"' | sudo -S apt-get remove -y "+package)
	return True
	
def install_package(package):
	RunLog.info( "\nInstall_package: "+package)
	if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
		return aptget_package_install(package)
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
		return yum_package_install(package)
	elif (current_distro == "SUSE Linux") or (current_distro == "openSUSE"):
		return zypper_package_install(package)
	else:
		RunLog.error((package + ": package installation failed!"))
		RunLog.info((current_distro + ": Unrecognised Distribution OS Linux found!"))
		return False

def install_package_file(file_path):
	RunLog.info( "\n Install_package_file: "+file_path)
	if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
		return install_deb(file_path)
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
		return install_rpm(file_path)
	elif (current_distro == "SUSE Linux") or (current_distro == "openSUSE"):
		return install_rpm(file_path)
	else:
		RunLog.error((package + ": package installation failed!"))
		RunLog.info((current_distro + ": Unrecognised Distribution OS Linux found!"))
		return False

def uninstall_package(package):
	RunLog.info( "\nUninstall package: "+package)
	if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
		return aptget_package_uninstall(package)
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
		return yum_package_uninstall(package)
	elif (current_distro == "SUSE Linux") or (current_distro == "openSUSE"):
		return zypper_package_uninstall(package)
	else:
		RunLog.error((package + ": package installation failed!"))
		RunLog.info((current_distro + ": Unrecognised Distribution OS Linux found!"))
		return False

def install_packages_singleVM():
	RunLog.info( "\nInstall packages singleVM ..")
	# Install the packages as per Distro
	if ((current_distro == "openSUSE") or (current_distro == "SUSE Linux")):
		packages_list = ("mysql-community-server","mysql","mysql-client","at","php5", "php5-mysql","php53","php53-mysql", "apache2","wget", "bc","xauth","libstdc++*","libstdc++.so.5","libstdc++33", "elfutils.x86_64", "libXp.x86_64","compat-libstdc++-33.x86_64", "compat-db.x86_64", "libXmu.x86_64","gtk2.x86_64", "pam.x86_64","libXft.x86_64", "libXtst.x86_64","gtk2-engines.x86_64", "elfutils-libs", "ksh", "compat-libstdc++-296")
	elif (current_distro == "Ubuntu"):
		packages_list = ("mysql-server","mysql-client", "mysql","php5", "php5-mysql","libstdc++6","elfutils","gtk2-engines", "mysql", "at", "mysql-libs", "mysql-devel", "php", "php-mysql", "libstdc++*", "compat-libstdc++-33.x86_64", "ksh", "bc", "xauth")
	else:
		packages_list = ("mysql-server", "mysql","at", "mysql-libs" "mysql-devel", "php", "php-mysql", "libstdc++*", "elfutils.x86_64", "libXp.x86_64", "compat-libstdc++-33.x86_64","bc","xauth", "compat-db.x86_64", "libXmu.x86_64", "gtk2.x86_64", "pam.x86_64", "libXft.x86_64", "libXtst.x86_64", "gtk2-engines.x86_64","elfutils-libs", "ksh", "compat-libstdc++-296")
	
	#print packages_list
	for package in packages_list:
		if(install_package(package)):
			RunLog.info( package + ": installed successfully")
		else:
			RunLog.error( package + ": installation Failed")
			#return False
	RunLog.info( "Install packages singleVM ..[done]")
	return True
	
def install_packages_backend():
	# Installing mysql package in OpenSUSE
	if (current_distro == "openSUSE"):
		packages_list = ("mysql-community-server","at","mysql-community-server-client","php5", "php5-mysql","php","php-mysql""apache2-mod_php5","apache2","wget","bc","xauth","libstdc++*","libstdc++.so.5", "elfutils.x86_64", "libXp.x86_64","compat-libstdc++-33.x86_64", "compat-db.x86_64", "libXmu.x86_64","gtk2.x86_64","pam.x86_64","libXft.x86_64", "libXtst.x86_64","gtk2-engines.x86_64", "elfutils-libs", "ksh", "compat-libstdc++-296")

	# Installing mysql package in SUSE Linux
	if (current_distro == "SUSE Linux"):
		packages_list = ("mysql","mysql-community-server-client","at","php53", "php53-mysql","apache2-mod_php5","apache2","wget","bc","xauth","libstdc++*","libstdc++33", "elfutils.x86_64", "libXp.x86_64","compat-libstdc++-33.x86_64", "compat-db.x86_64", "libXmu.x86_64","gtk2.x86_64","pam.x86_64","libXft.x86_64", "libXtst.x86_64","gtk2-engines.x86_64", "elfutils-libs", "ksh", "compat-libstdc++-296")

	# Installing mysql package in Ubuntu r Oracle or CentOS Distro
	if ((current_distro == "Ubuntu") or (current_distro == "Oracle") or (current_distro == "CentOS")):
		packages_list = ("mysql-server","mysql-client", "mysql","php5", "php5-mysql","libstdc++6","elfutils","gtk2-engines","mysql.x86_64","php","at", "php-mysql", "httpd" , "wget","libstdc++*","libstdc++.so.5", "elfutils.x86_64", "compat-libstdc++-296", "libXp.x86_64", "compat-libstdc++-33.x86_64", "compat-db.x86_64", "libXmu.x86_64", "gtk2.x86_64", "pam.x86_64", "libXft.x86_64", "libXtst.x86_64", "gtk2-engines.x86_64", "elfutils.x86_64", "elfutils-libs", "ksh", "compat-libstdc++-296")

	#Identify the packages list from "packages_list"
	for package in packages_list:
		if(install_package(package)):
			RunLog.info( package + ": installed successfully")
		else:
			RunLog.error( package + ": installation Failed")
			#return False
		
	return True

def install_packages_frontend():
	# Detect the Distro's -> OpenSUSE/SUSE Linux/Ubuntu and Ubuntu 
	if ((current_distro == "openSUSE") or (current_distro == "SUSE Linux")):
		packages_list = ("mysql-community-server-client","mysql-client","at","php5","php5-mysql","php53","php53-mysql","apache2-mod_php5","apache2","wget","bc","xauth","libstdc++*","libstdc++33","libstdc++.so.5","elfutils.x86_64", "libXp.x86_64","compat-libstdc++-33.x86_64", "compat-db.x86_64", "libXmu.x86_64","gtk2.x86_64","pam.x86_64","libXft.x86_64", "libXtst.x86_64","gtk2-engines.x86_64", "elfutils-libs", "ksh", "compat-libstdc++-296")
	elif (current_distro == "Ubuntu"):
		packages_list = ("mysql-client", "mysql","php5", "php5-mysql","libstdc++6","elfutils","gtk2-engines","mysql-client-core-5.5","at","libapache2-mod-php5","apache2","wget","php", "php-mysql", "libstdc++*","libstdc++.so.5", "compat-libstdc++-33.x86_64", "ksh", "bc", "xauth")
		
	# Detect the Distro's -> Oracle Redhat or Unbreakable / CentOS
	if ((current_distro == "Oracle") or (current_distro == "CentOS")):
		packages_list = ("mysql.x86_64","php","at","php-mysql", "httpd" , "wget","libstdc++*","libstdc++.so.5", "elfutils.x86_64", "compat-libstdc++-296", "libXp.x86_64", "compat-libstdc++-33.x86_64", "compat-db.x86_64", "libXmu.x86_64", "gtk2.x86_64", "pam.x86_64", "libXft.x86_64", "libXtst.x86_64", "gtk2-engines.x86_64", "elfutils.x86_64", "elfutils-libs", "ksh", "compat-libstdc++-296")

	#Identify the packages list from "packages_list"
	for package in packages_list:
		if(install_package(package)):
			RunLog.info( package + ": installed successfully")
		else:
			RunLog.error( package + ": installation Failed")

	RunLog.info( "Install packages singleVM ..[done]")
	return True

def exec_multi_cmds_local(cmd_list):
	f = open('/tmp/temp_script.sh','w')
	for line in cmd_list:
		f.write(line+'\n') 
	f.close()
	Run ("bash /tmp/temp_script.sh 2>&1 > /tmp/exec_multi_cmds_local.log")
	return file_get_contents("/tmp/exec_multi_cmds_local.log")

def exec_multi_cmds_local_sudo(cmd_list):
	f = open('/tmp/temp_script.sh','w')
	for line in cmd_list:
		f.write(line+'\n') 
	f.close()
	Run ("chmod +x /tmp/temp_script.sh")
	Run ("echo '"+vm_password+"' | sudo -S /tmp/temp_script.sh 2>&1 > /tmp/exec_multi_cmds_local_sudo.log")
	return file_get_contents("/tmp/exec_multi_cmds_local_sudo.log")

def set_javapath():
	RunLog.info( "\nSetting Java path")
	
	f = open('/tmp/setjavapath.sh','w')
	f.write('export PATH=$PATH:/opt/ibm/java-x86_64-60/jre/bin\n') 
	f.write('export JAVA_HOME=/opt/ibm/java-x86_64-60/jre\n') 
	f.write('export PATH=$PATH:/root/IBMWebSphere/apache-maven-2.2.1/bin\n') 
	f.write('export CLASSPATH=/root/IBMWebSphere/mysql-connector-java-5.1.18/mysql-connector-java-5.1.18.jar\n') 
	f.close()
	Run ("echo '"+vm_password+"\' | sudo -S mv /tmp/setjavapath.sh    /etc/profile.d/")
	RunLog.info( "Setting Java path...[done]")

def exec_multi_cmds_ssh(user_name, password, hostname, commands):
	try:
		s = pxssh.pxssh()
		log = ""
		s.login(hostname, user_name, password)
		for line in commands:
			s.sendline(line)
			s.prompt()
			log = log + s.before
			
	except pxssh.ExceptionPxssh as e:
		RunLog.error(("pxssh failed on login."))
		RunLog.error((e))
	
	s.logout()
	return log

def exec_cmd_remote_ssh(user_name, password, ip, command):
	child = pexpect.spawn ("ssh -t "+user_name+"@"+ip+" "+command)
	child.logfile = open("/tmp/mylog", "w")

	for j in range(0,6):
		child.timeout=6000
		#wait till expected pattern is found
		i = child.expect (['.assword', "yes/no",pexpect.EOF])
		if (i == 0):
			child.sendline (password)
			RunLog.info( "Password entered")
		elif (i == 1):
			child.sendline ("yes")
			RunLog.info( "yes sent")
		else:
			break
	return file_get_contents("/tmp/mylog")

def mvn_install():
	mvn_install_status = False
	RunLog.info( "Installing Maven..")

	cmds = ("cd /root/IBMWebSphere/daytrader-2.2.1-source-release", \
	"export CLASSPATH=/root/IBMWebSphere/mysql-connector-java-5.1.18/mysql-connector-java-5.1.18.jar", \
	"export PATH=$PATH:/root/IBMWebSphere/apache-maven-2.2.1/bin",\
	"export JAVA_HOME=/opt/ibm/java-x86_64-60/jre",\
	"export PATH=$PATH:/opt/ibm/java-x86_64-60/jre/bin",\
	"echo $PATH","echo $JAVA_HOME", \
	"echo $PWD", \
	"mvn install 2>&1 > /tmp/mvn.log")
	
	RunLog.info( exec_multi_cmds_local_sudo(cmds))
	
	for i in range(0,5):
		output = Run ("echo '"+vm_password+"\' | sudo -S tail -n 25 /tmp/mvn.log")
		if "BUILD SUCCESSFUL" in output:
			RunLog.info("Installing Maven..  [done]")
			mvn_install_status = True
			break
		else:
			RunLog.info(exec_multi_cmds_local_sudo(cmds))
			
	if mvn_install_status == False:
		RunLog.error( "Installing Maven..  [failed]")
		print Run ("echo '"+vm_password+"\' | sudo -S cat /tmp/mvn.log")
		exit()

def setup_websphere():
	RunLog.info( "\nSetting up Websphere ..")
	RunLog.info( "Extracting /tmp/IBMWebSphere.tar.gz")
	JustRun ("echo '"+vm_password+"' | sudo -S tar -xvf IBMWebSphere.tar.gz -C /root")
	if (current_distro == "Ubuntu"):
		install_package_file("/root/IBMWebSphere/ibm-java-x86-64-sdk_6.0-10.1_amd64.deb")
	else:
		install_package_file("/root/IBMWebSphere/ibm-java-x86_64-sdk-6.0-9.1.x86_64.rpm")
		
	set_javapath()

	RunLog.info( "Installing Websphere"	)
	RunLog.info( exec_multi_cmds_local(("export CLASSPATH=$CLASSPATH:/root/IBMWebSphere/mysql-connector-java-5.1.18/mysql-connector-java-5.1.18.jar", "export PATH=$PATH:/root/IBMWebSphere/apache-maven-2.2.1/bin", "export JAVA_HOME=/opt/ibm/java-x86_64-60/jre", "export PATH=$PATH:/opt/ibm/java-x86_64-60/jre/bin", "echo $PATH", "echo $CLASSPATH", "echo '"+vm_password+"' | sudo -S env PATH=$PATH /root/IBMWebSphere/wasce_setup-2.1.1.6-unix.bin -i silent -r responseFile.properties")))
	RunLog.info( "\nSetting up Websphere ..[done]")

def mysql_secure_install(db_root_password):
	RunLog.info( "\nStarting mysql_secure_install")
	child = pexpect.spawn ("/usr/bin/mysql_secure_installation")
	
	#wait till expected pattern is found
	i = child.expect (['enter for none', pexpect.EOF])
	if (i == 0):
		child.sendline ("")
		RunLog.info( "'enter for none' command successful\n")
	
	#wait till expected pattern is found
	try:
		i = child.expect (['\? \[Y\/n\]', pexpect.EOF])
		if (i == 0):
			child.sendline ("Y")	#send y
			RunLog.info( "'Set root password' command successful\n"+child.before)
	except:
		RunLog.error( "exception:" + str(i))
		return	

	for x in range(0, 10):
		#wait till expected pattern is found
		try:
			i = child.expect (['\? \[Y\/n\]', 'password:', pexpect.EOF])
			if (i == 0):
				child.sendline ("Y")	#send y
			elif(i == 1):
				child.sendline (db_root_password)	#send y
			else:
				break
		except:
			RunLog.error( "exception:" + str(i))
			return

def create_db(db_name, db_root_password):
	RunLog.info( "\nCreating a database on MySQL with name "+db_name)
	child = pexpect.spawn ('mysql -uroot -p'+db_root_password)

		#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ('CREATE DATABASE '+db_name+";")
		RunLog.info( "'CREATE DATABASE' command successful\n"+child.before)
		#wait till expected pattern is found -> Show Databases
		i = child.expect (['mysql>', pexpect.EOF])
		if (i == 0):
			child.sendline ("show databases;")      #send y
		RunLog.info( "'show databases' command successful\n"+child.before)
		#wait till expected pattern is found -> exit
		i = child.expect (['mysql>', pexpect.EOF])
		if (i == 0):
			child.sendline ("exit")
		
		RunLog.info( "Creating a database on MySQL with name "+db_name+"..[done]")
		return True

	RunLog.error( "Creating a database on MySQL with name "+db_name+"..[failed]")
	return False

def create_user_db(db_name, db_root_password, db_hostname, db_username, db_password):
	RunLog.info( "\nCreating user with username: "+db_username+", on MySQL database name: "+db_name)
	child = pexpect.spawn ('mysql -uroot -p'+db_root_password)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ('CREATE USER '+db_username+"@"+db_hostname+";") #send y
		RunLog.info( "'CREATE USER' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("GRANT ALL PRIVILEGES ON "+db_name+".* TO '"+db_username+"'@'"+db_hostname+"' IDENTIFIED by '"+db_password+"' WITH GRANT OPTION;")
		RunLog.info( "'GRANT ALL PRIVILEGES' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("FLUSH PRIVILEGES;")    #send y
		RunLog.info( "'FLUSH PRIVILEGES' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("show databases;")      #send y
		RunLog.info( "'show databases' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("select host,user from mysql.user;")    #send y
		RunLog.info( "'select user' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("exit") #send y
		RunLog.info( "'CREATE USER' command successful\n"+child.before)
	
	RunLog.info( "Creating user with username: "+db_username+", on MySQL database name: "+db_name+"...[done]")
	
def get_services_status(service):
	current_status = "unknown"
	if ((detect_distro() == 'SUSE Linux') or (detect_distro() == 'openSUSE')):
		service_command = "/etc/init.d/"
	else:
		service_command = "service "  #space character after service is mandatory here.
		
	RunLog.info( "get service func : " + service)
	output = Run("echo '"+vm_password+"' | sudo -S "+service_command+service+" status")
	outputlist = re.split("\n", output)
	 
	for line in outputlist:
		#start condition
		if (re.match(re.escape(service)+r'.*start\/running', line, re.M|re.I) or \
			re.match(re.escape(service)+r'.*is running.*', line, re.M|re.I) or \
			re.match(r'Starting.*'+re.escape(service)+r'.*OK',line,re.M|re.I) or \
			re.match(r'.*'+re.escape(service)+r'.*running.*', line, re.M|re.I) or \
			re.match(r'.*active \(running\).*', line, re.M|re.I)):
			RunLog.info((service+": service is running\n"+line))
			current_status = "running"
			
		if (re.match(re.escape(service)+r'.*Stopped.*',line,re.M|re.I) or \
			re.match(re.escape(service)+r'.*stop\/waiting', line, re.M|re.I) or \
			re.match(r'.*'+re.escape(service)+r'.*unused.*', line, re.M|re.I) or \
			re.match(r'.*inactive \(dead\).*', line, re.M|re.I)):
			RunLog.info((service+": service is stopped\n"+line))
			current_status = "stopped"
	
	if(current_status == "unknown"):
		output = Run("pgrep "+service+" |wc -l")
		if (int(output) > 0):
			RunLog.info("Found '"+output+"' instances of service: "+service+" running.")
			RunLog.info(service+": service is running\n")
			current_status = "running"
		else:
			RunLog.info("No instances of service: "+service+" are running.")
			RunLog.info(service+": service is stopped\n")
			current_status = "stopped"
	
	return (current_status)

def set_services_status(service, status):
	current_status = "unknown"
	set_status = False

	RunLog.info( "service :" + service)
	if ((detect_distro() == 'SUSE Linux') or (detect_distro() == 'openSUSE')):
		service_command = "/etc/init.d/"
	else:
		service_command = "service "  #space character after service is mandatory here.

	RunLog.info( "service status:"+ status)
	output = Run("echo '"+vm_password+"' | sudo -S "+service_command+service+" "+status)
	current_status = get_services_status(service)
	RunLog.info( "current_status -:" + current_status)
	
	if((current_status == "running") and (status == "restart" or status == "start" )):
		set_status = True
	elif((current_status == "stopped") and (status == "stop")):
		set_status = True
	else:
		RunLog.error( "set_services_status failed\nError log: \n" + output)

	return (set_status, current_status)

def deploy_daytrader():
	cmds = ("export CLASSPATH=/root/IBMWebSphere/mysql-connector-java-5.1.18/mysql-connector-java-5.1.18.jar", \
	"export PATH=$PATH:/root/IBMWebSphere/apache-maven-2.2.1/bin",\
	"export JAVA_HOME=/opt/ibm/java-x86_64-60/jre",\
	"export PATH=$PATH:/opt/ibm/java-x86_64-60/jre/bin",\
	"echo $PATH","echo $JAVA_HOME", \
	"/opt/IBM/WebSphere/AppServerCommunityEdition/bin/deploy.sh --user system --password manager deploy /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/daytrader-ear/target/daytrader-ear-2.2.1.ear  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml")
	output = exec_multi_cmds_local_sudo(cmds)
	if(output.rfind == "TradeJMS"):
		RunLog.info('** Daytrader setup is completed succesfully **\n ' + output)
	else:
		RunLog.error('** Daytrader setup is not completed succesfully **\n ' + output)
	return output

def start_ibm_websphere():
	RunLog.info( "\nStarting websphere..")
	output = Run("echo '"+vm_password+"' | sudo -S /opt/IBM/WebSphere/AppServerCommunityEdition/bin/startup.sh")
	if "Exception" in output:
		RunLog.error("Failure Starting IBM Websphere")
		result = False
		raise Exception
	else:
		RunLog.info("IBM Websphere Server Started....wait for 100 seconds to deploy application")
	import time
	time.sleep(100)
	RunLog.info( "\nStarting websphere.. [done]")
	return True

def stop_ibm_websphere():
	RunLog.info( "\nStopping websphere..")
	output = Run("echo '"+vm_password+"' | sudo -S /opt/IBM/WebSphere/AppServerCommunityEdition/bin/./stop-server.sh")
	if "Exception" in output:
		RunLog.error("Failure Stoping IBM Websphere")
		result=False
		raise Exception
	else:
		RunLog.info("Successfully Stopped IBM WebSphere")
	RunLog.info( "Stopping websphere.. [done]")

def install_ibm_mySql_connector():
	RunLog.info( "\nInstalling MySQL Java connector..")
	output = exec_multi_cmds_local_sudo(("sh /opt/IBM/WebSphere/AppServerCommunityEdition/bin/deploy.sh --user system --password manager install-library --groupId mysql /root/IBMWebSphere/mysql-connector-java-5.1.18/mysql-connector-java-5.1.18.jar","\n"))
	
	if ("Installed mysql" in output):
		RunLog.info( "Mysql connector java jar installed successfully.")
	else:
		RunLog.error( "Mysql connector java jar installation failed")
		exit()
		
	RunLog.info( "Installing MySQL Java connector.. [done]")

def setup_daytrader():
	RunLog.info( "\nSetting up daytrader ..")
	mvn_install()
							
	RunLog.info( "\nConfiguring daytrader-mysql-xa-plan.xml")
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S rm -rf /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/daytrader-war/src/main/webapp/dbscripts/mysql/Table.ddl"))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S cp /root/IBMWebSphere/Table.ddl /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/daytrader-war/src/main/webapp/dbscripts/mysql/"))
	RunLog.info( exec_multi_cmds_local_sudo(("mysql -u"+daytrader_db_username+" -p"+daytrader_db_password+" -h"+daytrader_db_hostname+" "+ daytrader_db_name + "  </root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/daytrader-war/src/main/webapp/dbscripts/mysql/Table.ddl","\n")))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S sed -i 's/\(.*<config-property-setting name=\"UserName\">\).*\(<\/config-property-setting>\)/\\1"+daytrader_db_username+"\\2/g'  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml"))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S sed -i 's/\(.*<config-property-setting name=\"Password\">\).*\(<\/config-property-setting>\)/\\1"+daytrader_db_password+"\\2/g'  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml"))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S sed -i 's/\(.*<config-property-setting name=\"ServerName\">\).*\(<\/config-property-setting>\)/\\1"+daytrader_db_hostname+"\\2/g'  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml"))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S sed -i 's/\(.*<config-property-setting name=\"DatabaseName\">\).*\(<\/config-property-setting>\)/\\1"+daytrader_db_name+"\\2/g'  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml"))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S sed -i 's/\(.*<host>\).*\(<\/host>\)/\\1"+daytrader_db_hostname+"\\2/g'  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml"))
	RunLog.info( Run ("echo '"+vm_password+"' | sudo -S sed -i 's/<version>5.1.7<\/version>/<version>5.1.18<\/version>/g'  /root/IBMWebSphere/daytrader-2.2.1-source-release/assemblies/javaee/plans/target/classes/daytrader-mysql-xa-plan.xml"))

	start_ibm_websphere()
	RunLog.info( install_ibm_mySql_connector())
	RunLog.info( deploy_daytrader())
	RunLog.info( "Setting up daytrader .. [done]")

def put_file_sftp(user_name, password, ip, file_name):
	child = pexpect.spawn ("sftp "+user_name+"@"+ip)
	child.logfile = open("/tmp/mylog", "w")
	file_sent = False

	for j in range(0,6):
		#wait till expected pattern is found
		#i = child.expect (['.assword', ".*>", "yes/no",pexpect.EOF])
		i = child.expect (['.assword', ".*>", "yes/no",pexpect.EOF,pexpect.TIMEOUT], timeout=300)
		if (i == 0):
			child.sendline (password)
			RunLog.info( "Password entered")
		elif (i == 2):
			child.sendline ("yes")
			RunLog.info( "yes sent")
		elif (i == 1):
			if file_sent == True:
				child.sendline ("exit")
				break
			child.sendline ("put "+file_name)
			RunLog.info( "put file succesful")
			file_sent = True
		elif (i == 4):
			continue

	return file_get_contents( "/tmp/mylog")
	
def get_file_sftp(user_name, password, ip, file_name):
	child = pexpect.spawn ("sftp "+user_name+"@"+ip)
	child.logfile = open("/tmp/mylog", "w")
	file_sent = False

	for j in range(0,6):
		#i = child.expect (['.assword', ".*>", "yes/no",pexpect.EOF])
		i = child.expect (['.assword', ".*>", "yes/no",pexpect.EOF,pexpect.TIMEOUT], timeout=300)
		if (i == 0):
			child.sendline (password)
			RunLog.info( "Password entered")
		elif (i == 2):
			child.sendline ("yes")
			RunLog.info( "yes sent")
		elif (i == 1):
			if file_sent == True:
				child.sendline ("exit")
				break
			child.sendline ("get "+file_name)
			RunLog.info( "get file succesful")
			file_sent = True
		elif (i == 4):
			continue

	return file_get_contents( "/tmp/mylog")

def setup_Daytrader_E2ELoadBalance_backend(front_end_users):
	# Installing packages in Backend VM Role
	if (not install_packages_backend()):
		RunLog.error( "Failed to install packages for Backend VM Role")
	setup_websphere()
	set_services_status(service_mysqld_name, "start")
	rtrn = get_services_status(service_mysqld_name)
	if (rtrn != "running"):
		RunLog.error( "Failed to start mysqld")
		exit()

	# To make to connection from backend to other IP's ranging from 0.0.0.0
	#bind = Run("echo '"+vm_password+"' | sudo -S sed -i 's/\(bind-address.*= \)\(.*\)/\\1 0.0.0.0/' /etc/mysql/my.cnf | grep bind")
	bind = Run("echo 'Redhat.Redhat.777' | sudo -S sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/my.cnf | grep bind")
	Run("echo '"+vm_password+"' | sudo -S service mysql restart")
	
	# Installing the "mysql secure installation" in other Distro's (not in Ubuntu)
	if (current_distro != 'Ubuntu'):
		mysql_secure_install(daytrader_db_root_password)
			
	# Creating database using mysql
	create_db(daytrader_db_name, daytrader_db_root_password)
	
	# Creating users to access database from mysql
	#for ip in front_end_users:
		#create_user_db(daytrader_db_name, daytrader_db_root_password, ip, daytrader_db_username, daytrader_db_password)
	create_user_db(daytrader_db_name, daytrader_db_root_password, "%", daytrader_db_username, daytrader_db_password)
	RunLog.info( "Keeping 'mysqld' in startup..")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig --add mysqld")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig mysqld on")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig mysql on")
	RunLog.info( "Keeping 'mysqld' in startup..[done]")
	
def setup_Daytrader_E2ELoadBalance_frontend():
	# Installing packages in Front-end VM Role's
	if (not install_packages_frontend()):
		RunLog.error( "Failed to install packages for Frontend VM Role")
		exit

	set_services_status(service_httpd_name, "start")
	rtrn = get_services_status(service_httpd_name)

	if (rtrn != "running"):
		RunLog.error( "Failed to start :" + service_httpd_name)
		exit
	setup_websphere()
	setup_daytrader()

def setup_Daytrader_singleVM():
	if(install_packages_singleVM() == False):
		print "Abort"
		exit()
	# Installing packages in Backend VM Role
	if (not install_packages_backend()):
		RunLog.error( "Failed to install packages for Backend VM Role")
	set_services_status(service_mysqld_name, "start")
	rtrn = get_services_status(service_mysqld_name)
	if (rtrn != "running"):
		RunLog.error( "Failed to start mysqld")
		exit()

	# To make to connection from backend to other IP's ranging from 0.0.0.0
	#bind = Run("echo 'rdPa$$w0rd' | sudo -S sed -i 's/\(bind-address.*= \)\(.*\)/\\1 0.0.0.0/' /etc/mysql/my.cnf | grep bind")
	bind = Run("echo 'Redhat.Redhat.777' | sudo -S sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/my.cnf | grep bind")
	Run("echo '"+vm_password+"' | sudo -S service mysql restart")
	
	# Installing the "mysql secure installation" in other Distro's (not in Ubuntu)
	if (current_distro != 'Ubuntu'):
		mysql_secure_install(daytrader_db_root_password)
			
	# Creating database using mysql
	create_db(daytrader_db_name, daytrader_db_root_password)
	
	# Creating users to access database from mysql
	create_user_db(daytrader_db_name, daytrader_db_root_password, daytrader_db_hostname, daytrader_db_username, daytrader_db_password)
	RunLog.info( "Keeping 'mysqld' in startup..")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig --add mysqld")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig mysqld on")
	RunLog.info( "Keeping 'mysqld' in startup..[done]")
	# Installing packages in Front-end VM Role's
	if (not install_packages_frontend()):
		RunLog.error( "Failed to install packages for Frontend VM Role")
		exit

	set_services_status(service_httpd_name, "start")
	rtrn = get_services_status(service_httpd_name)

	if (rtrn != "running"):
		RunLog.error( "Failed to start :" + service_httpd_name)
		exit
	setup_websphere()
	setup_daytrader()	
	#Keeping the server ins the startup and rebooting the VM.
	output = Run('cat '+startup_file+'   | grep "^exit"')
	if "exit" in output:
		RunLog.info( output)
		output = exec_multi_cmds_local_sudo(("sed -i 's_^exit 0_sh /opt/IBM/WebSphere/AppServerCommunityEdition/bin/startup.sh\\nexit 0_' "+startup_file,"\n"))
	else:
		RunLog.info( "exit not found")
		exec_multi_cmds_local_sudo(('echo "sh /opt/IBM/WebSphere/AppServerCommunityEdition/bin/startup.sh" >>  '+startup_file,'\n'))
	RunLog.info( "Rebooting the frontend....\n")
	RunLog.info( exec_multi_cmds_local_sudo(["reboot"]))

def update_python_and_install_pexpect():
	python_install_commands = (	"wget --no-check-certificate http://python.org/ftp/python/2.7.2/Python-2.7.2.tgz", \
	"tar -zxvf Python-2.7.2.tgz", \
	"cd Python-2.7.2", \
	"./configure --prefix=/opt/python2.7 --enable-shared", \
	"make", \
	"make altinstall", \
	'echo "/opt/python2.7/lib" >> /etc/ld.so.conf.d/opt-python2.7.conf', \
	"ldconfig", \
	"cd ..", \
	'if [ -f "/opt/python2.7/bin/python2.7" ];then ln -fs /opt/python2.7/bin/python2.7 /usr/bin/python ; fi'
	)

	pexpect_install_commands = ("wget http://kaz.dl.sourceforge.net/project/pexpect/pexpect/Release%202.3/pexpect-2.3.tar.gz", \
	"tar -xvf pexpect-2.3.tar.gz", \
	"cd pexpect-2.3", \
	"python setup.py install")

	pckg_list = ("readline-devel", "openssl-devel", "gmp-devel", "ncurses-devel", "gdbm-devel", "zlib-devel", "expat-devel",\
	"libGL-devel", "tk", "tix", "gcc-c++", "libX11-devel", "glibc-devel", "bzip2", "tar", "tcl-devel", "tk-devel", \
	"pkgconfig", "tix-devel", "bzip2-devel", "sqlite-devel", "autoconf", "db4-devel", "libffi-devel", "valgrind-devel")

	RunLog.info( "Installing packages to build python..")
	for pkg in pckg_list:
		install_package(pkg)
		
	RunLog.info( "Installing packages ..[done]")
		
	RunLog.info( "Installing python 2.7.2")
	RunLog.info( exec_multi_cmds_local_sudo(python_install_commands))

	output = Run ("python -V 2>&1")
	if "2.7.2" not in output:
		RunLog.error( "Installing python 2.7.2 .. [failed!]\nAborting the script..\n")
		exit()
	else:
		RunLog.info( "Installing python 2.7.2 .. [done]")
		
	RunLog.info( "Installing pexpect from source..")

	exec_multi_cmds_local_sudo(pexpect_install_commands)
	RunLog.info( "Installing pexpect from source.. [done]")

def collect_logs():
	Run("mkdir logs")
	Run("cp -f /tmp/*.log logs/")
	Run("cp -f *.XML logs/")
	if (sys.argv[1] == 'loadbalancer_setup'):
		for ip in front_endVM_ips:
			exec_cmd_remote_ssh(vm_username, vm_password, ip, "mv Runtime.log "+ip+"-Runtime.log")
			get_file_sftp(vm_username, vm_password, ip, ip+"-Runtime.log")
	Run("cp -f *.log logs/")
	Run("cp -f dtr_test.txt logs/")
	Run("tar -czvf logs.tar.gz logs/")
	
def get_username_password_from_xml():
	global vm_username
	global vm_password
	if(not os.path.isfile("Daytrader_install.XML")):
		RunLog.error("File not found Daytrader_install.XML")
		exit()
	output = file_get_contents("Daytrader_install.XML")
	outputlist = re.split("\n", output)

	for line in outputlist:
		if "</username>" in line:
			matchObj = re.match( r'<username>(.*)</username>', line, re.M|re.I)
			vm_username = matchObj.group(1)
		elif "</password>" in line:
			matchObj = re.match( r'<password>(.*)</password>', line, re.M|re.I)
			vm_password = matchObj.group(1)
			
def verify_daytrader_instllation():
	if (sys.argv[1] == 'loadbalancer_setup'):
		ips = front_endVM_ips
	elif (sys.argv[1] == "singleVM_setup"): 
		ips = ["127.0.0.1"]
	else:
		return 1
		
	Run("mkdir /tmp/verify_dtr/")
	for ip in ips:
		dtr_url = "http://"+ip+":8080/daytrader"
		Run("wget -t 2 -T 3 "+dtr_url+" -O /tmp/verify_dtr/"+ip+".html")
	output = Run("grep -irun 'DayTrader' /tmp/verify_dtr/ | wc -l")
	Run("rm -rf  /tmp/verify_dtr/")
	output = output.rstrip('\n')

	if( int(output) == len(ips)):
		print "DTR_INSTALL_PASS" 
		Run("echo 'DTR_INSTALL_PASS' > dtr_test.txt")
		return 0
	else:
		print "DTR_INSTALL_FAIL" 
		Run("echo 'DTR_INSTALL_FAIL' > dtr_test.txt")
		return 1

def show_usage():
	print "Error: Invalid usage"
	print "Usage: \"python "+__file__+" singleVM_setup\" for single VM Daytrader Setup"
	print "Usage: \"python "+__file__+" loadbalancer_setup\" for locagbalanced Daytrader Setup"
	print "Usage: \"python "+__file__+" frontend_setup <back end vm ip>\" frontend setup for locadbalanced Daytrader Setup"
	exit()

def RunTest():
	ip = "127.0.0.1"
	global daytrader_db_hostname
	global front_endVM_ips
	front_endVM_username    = vm_username
	front_endVM_password    = vm_password
	file_name       = __file__

	if len(sys.argv) > 1 :
		if sys.argv[1] == 'loadbalancer_setup':
			if len(sys.argv) == 2 :
				output = file_get_contents("Daytrader_install.XML")
				outputlist = re.split("\n", output)
				for line in outputlist:
					if "</back_endVM_ip>" in line:
						matchObj = re.match( r'<back_endVM_ip>(.*)</back_endVM_ip>', line, re.M|re.I)
						back_endVM_ip = matchObj.group(1)
						daytrader_db_hostname = back_endVM_ip
					elif "</front_endVM_ips>" in line:
						matchObj = re.match( r'<front_endVM_ips>(.*)</front_endVM_ips>', line, re.M|re.I)
						front_endVM_ips = str.split(matchObj.group(1))
						RunLog.info( "frontend ips : ")
					elif "</front_endVM_username>" in line:
						matchObj = re.match( r'<front_endVM_username>(.*)</front_endVM_username>', line, re.M|re.I)
						front_endVM_username = matchObj.group(1)
					elif "</front_endVM_password>" in line:
						matchObj = re.match( r'<front_endVM_password>(.*)</front_endVM_password>', line, re.M|re.I)
						front_endVM_password = matchObj.group(1)
											
				RunLog.info( "\nStarting loadbalancer_setup")
				RunLog.info( "Starting backend VM setup")
				setup_Daytrader_E2ELoadBalance_backend(front_endVM_ips)
				
				frontend_count = 1		
				for ip in front_endVM_ips:
					RunLog.info("**********************************************************")
					RunLog.info("\nConfiguring frontend"+str(frontend_count)+" at "+ip+":\n")
					#TODO fix ssh tcp alive issue
					RunLog.info( "Copying "+__file__+" to "+ip)
					RunLog.info( put_file_sftp(front_endVM_username, front_endVM_password, ip, __file__))
					RunLog.info( "Copying "+"azuremodules.py"+" to "+ip)
					RunLog.info( put_file_sftp(front_endVM_username, front_endVM_password, ip, "azuremodules.py"))
					RunLog.info("Copying Daytrader_install.XML to "+ ip)
					RunLog.info(put_file_sftp(front_endVM_username, front_endVM_password, ip, "Daytrader_install.XML"))
					RunLog.info( "Copying "+"IBMWebSphere.tar.gz"+" to "+ip)
					RunLog.info( put_file_sftp(front_endVM_username, front_endVM_password, ip, "IBMWebSphere.tar.gz"))
					RunLog.info( exec_cmd_remote_ssh(front_endVM_username, front_endVM_password, ip, "mv IBMWebSphere.tar.gz /tmp/IBMWebSphere.tar.gz"))
					RunLog.info( "\nStarting frontend VM setup on "+ip)
					RunLog.info( exec_cmd_remote_ssh(front_endVM_username, front_endVM_password, ip, "python "+file_name+" frontend_setup "+ back_endVM_ip))
					frontend_count = frontend_count+1
					
			else:
				show_usage()
		elif sys.argv[1] == 'frontend_setup':
			if len(sys.argv) == 3:
				daytrader_db_hostname = sys.argv[2]
				setup_Daytrader_E2ELoadBalance_frontend()
#				#Keeping the server ins the startup and rebooting the VM.
				output = Run('cat '+startup_file+'   | grep "^exit"')
				print output
				if "exit" in output:
					print output
					output = exec_multi_cmds_local_sudo(("sed -i 's_^exit 0_sh /opt/IBM/WebSphere/AppServerCommunityEdition/bin/startup.sh\\nexit 0_' "+startup_file,"\n"))					
				else:
					RunLog.info( "exit not found")
					exec_multi_cmds_local_sudo(('echo "sh /opt/IBM/WebSphere/AppServerCommunityEdition/bin/startup.sh" >>  '+startup_file,'\n'))
				RunLog.info( "Rebooting the frontend....\n")
				RunLog.info( exec_multi_cmds_local_sudo(["reboot"]))
			elif len(sys.argv) < 3:
				print "Back end IP missing"
				show_usage()
			else:
				show_usage()
		elif sys.argv[1] == "singleVM_setup":
			if len(sys.argv) == 2 :
				RunLog.info( "\nStarting single VM setup")
				setup_Daytrader_singleVM()
			else:
				show_usage()
		else:
			show_usage()
	else:
		show_usage()

# Code execution Start from here
get_username_password_from_xml()
set_variables_OS_dependent()
current_distro = detect_distro()
update_repos()
disable_selinux()
disable_iptables()
uninstall_package("java*")
#check for availability of pexpect module
try:
	imp.find_module('pexpect')
	import pexpect
except ImportError:
	RunLog.error( "Unable to found pexpect module")
	RunLog.info( "Trying to install")
	RunLog.info( "pexpect_pkg_name: " + pexpect_pkg_name)
	if(not install_package(pexpect_pkg_name)):
		RunLog.info( "pexpect module could not be installed")
		RunLog.info( "Installing pexpect from source..")
		update_python_and_install_pexpect()
		RunLog.info( "\n\nInvoking the script with new python:....")
		RunLog.info( Run("python "+__file__+" "+' '.join(sys.argv[1:])))
		exit()

import pexpect
#Getting IBMWebSphere.tar.gz from IBM-dont-delete VM
RunLog.info( get_file_sftp("azureuser", "rdPa$$w0rd", "138.91.168.232", "IBMWebSphere.tar.gz"))

RunTest()
#main()
#exit(0)
 
result = verify_daytrader_instllation()
if (sys.argv[1] != 'frontend_setup'):
	collect_logs()
exit(result)