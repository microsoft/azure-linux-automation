#!/usr/bin/python
import re
import time
import imp
import sys
from azuremodules import *

#OS independent variables
wdp_downlink = "http://wordpress.org/latest.tar.gz"
wdp_db_root_password = "wordpress_root_password"
wdp_db_name		= "wordpressdb"
wdp_db_hostname = "localhost"
wdp_db_username = "wordpress_user"
wdp_db_password = "wordpress_password"
front_endVM_ips	= "unknown"
vm_username		= "unknown"
vm_password		= "unknown"

#OS dependent variables
wdp_install_folder	= "unknown"
pexpect_pkg_name	= "unknown"
current_distro		= "unknown"
service_httpd_name	= "unknown"
service_mysqld_name	= "unknown"

def set_variables_OS_dependent():
	global current_distro
	global pexpect_pkg_name
	global service_httpd_name
	global service_mysqld_name

	current_distro = DetectDistro()
	# Identify the Distro to Set OS Dependent Variables
	if ((current_distro == "Oracle") or (current_distro == "CentOS")):
		pexpect_pkg_name		= "pexpect"
		service_httpd_name	  = "httpd"
		service_mysqld_name 	= "mysqld"
	elif (current_distro == "Ubuntu"):
		pexpect_pkg_name		= "python-pexpect"
		service_httpd_name	  = "apache2"
		service_mysqld_name		= "mysql"
	elif ((current_distro == "openSUSE") or (current_distro == "SUSE Linux")):
		pexpect_pkg_name		= "python-pexpect"					 #check package name for suse
		service_httpd_name	  = "apache2"
		service_mysqld_name		= "mysql"

def exec_multi_cmds_local(cmd_list):
	RunLog.info("Executing multi commands as local")
	f = open('/tmp/temp_script.sh','w')
	for line in cmd_list:
		f.write(line+'\n')
	f.close()
	Run ("bash /tmp/temp_script.sh 2>&1 > /tmp/exec_multi_cmds_local.log")
	return file_get_contents("/tmp/exec_multi_cmds_local.log")

def exec_multi_cmds_local_sudo(cmd_list):
	RunLog.info("Executing multi commands local as sudo")
	f = open('/tmp/temp_script.sh','w')
	f.write("export PATH=$PATH:/sbin:/usr/sbin"+'\n')
	for line in cmd_list:
		f.write(line+'\n')
	f.close()
	Run ("chmod +x /tmp/temp_script.sh")
	Run ("echo '"+vm_password+"' | sudo -S /tmp/temp_script.sh 2>&1 > /tmp/exec_multi_cmds_local_sudo.log")
	return file_get_contents("/tmp/exec_multi_cmds_local_sudo.log")

def yum_package_install(package):
	RunLog.info("Installing Package: " + package)
	output = Run("echo '"+vm_password+"' | sudo -S yum install -y "+package)
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
		#package is not found on the repository
		elif (re.match(r'^No package '+ re.escape(package)+ r' available', line, re.M|re.I)):
			break

	#Consider package installation failed if non of the above matches.
	RunLog.info(package + ": package installation failed!\n")
	RunLog.info("Error log: "+output)
	return False

def aptget_package_install(package):
	RunLog.info("Installing Package: " + package)
	# Identify the package for Ubuntu
	# We Haven't installed mysql-secure_installation for Ubuntu Distro
	if (package == 'mysql-server'):
		RunLog.info ("apt-get function package:" + package)
		fp = open ("/tmp/text.sh","w")
		fp.write("export DEBIAN_FRONTEND=noninteractive\n")
		fp.write("echo mysql-server mysql-server/root_password select " + wdp_db_root_password + " | debconf-set-selections\n")
		fp.write("echo mysql-server mysql-server/root_password_again select " + wdp_db_root_password  + "| debconf-set-selections\n")
		fp.write("echo '"+vm_password+"' | sudo -S apt-get install -y  --force-yes mysql-server\n")
		fp.close()
		output = Run("echo '"+vm_password+"' | sudo -S sh /tmp/text.sh")
		Run("rm -rf /tmp/text.sh")
	else:
		output = Run("echo '"+vm_password+"' | sudo -S apt-get install -y --force-yes "+package)

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
	RunLog.info("Installing Package: " + package)
	output = Run("echo '"+vm_password+"' | sudo -S zypper --non-interactive in "+package)
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
		#package is not found on the repository
		elif (re.match(r'^No provider of \''+ re.escape(package) + r'\' found', line, re.M|re.I)):
			break

	#Consider package installation failed if non of the above matches.
	RunLog.info(package + ": package installation failed!\n")
	RunLog.info("Error log: "+output)
	return False

def install_package(package):
	RunLog.info("Installing Packages based on Distro's")
	if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
		return aptget_package_install(package)
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
		return yum_package_install(package)
	elif (current_distro == "SUSE Linux") or (current_distro == "openSUSE"):
		return zypper_package_install(package)
	else:
		RunLog.info(package + ": package installation failed!")
		RunLog.info(current_distro + ": Unrecognised Distribution OS Linux found!")
		return False

def download_url(url, destination_folder):
	RunLog.info("Downloading the WordPress URL...")
	rtrn = Run("echo '"+vm_password+"' | sudo -S wget -P "+destination_folder+" "+url+ " 2>&1")
	# Faild to find wget package
	if(rtrn.rfind("wget: command not found") != -1):
		install_package("wget")
		rtrn = Run("echo '"+vm_password+"' | sudo -S wget -P "+destination_folder+" "+url+ " 2>&1")

	if( rtrn.rfind("100%") != -1):
		return True
	else:
		print rtrn
		return False

def install_packages_singleVM():
	global wdp_install_folder
	RunLog.info("Installing Packages in SingleVM")
	# Install the packages as per Distro
	if ((current_distro == "openSUSE") or (current_distro == "SUSE Linux")):
		if (current_distro == "openSUSE"):
			packages_list = ("mysql-community-server","php5", "php5-mysql", "apache2-mod_php5","wget")
		else:
			packages_list = ("mysql" ,"php53", "php53-mysql","apache2-mod_php53","apache2","wget")
	# Ubuntu Distro
	elif (current_distro == "Ubuntu"):
		packages_list = ("mysql-server","php5", "php5-mysql", "apache2","wget")
	else:
		packages_list = ("mysql-server","php", "php-mysql", "httpd" , "wget")

	for package in packages_list:
		if(install_package(package)):
			RunLog.info(package + ": installed successfully")
		else:
			RunLog.info(package + ": installation Failed")

	# get_apache_document_root() should be called only after installation of apache.
	wdp_install_folder = get_apache_document_root()
	if(wdp_install_folder == None):
		RunLog.error("Unable to find wdp_install_folder..")
		RunLog.error("Aborting the installation.")
		end_the_script()

	if(download_url(wdp_downlink, wdp_install_folder)):
		RunLog.info("Wordpress package downloaded successfully")
		Run("echo '"+vm_password+"' | sudo -S tar -xvf "+wdp_install_folder+"/latest.tar.gz -C "+wdp_install_folder)
	else:
		RunLog.info("Wordpress package downloaded failed.")
		return False

	return True

def get_apache_document_root():
	document_root_list = ["/var/www/", "/var/www/html/", "/srv/www/htdocs/"]
	apache_path = None
	
	for folder in document_root_list:
		if(os.path.isdir(folder)):
			apache_path = folder
	return apache_path

def install_packages_backend():
	RunLog.info("Installing Packages in Backend VM ")
	# Installing mysql package in OpenSUSE
	if (current_distro == "openSUSE"):
		package = "mysql-community-server"

	# Installing mysql package in SUSE Linux
	if (current_distro == "SUSE Linux"):
		package = "mysql"

	# Installing mysql package in Ubuntu r Oracle or CentOS Distro
	if ((current_distro == "Ubuntu") or (current_distro == "Oracle") or (current_distro == "CentOS")):
		package = "mysql-server"
		
	install_package("wget")

	# Searching the Package from the list
	if(install_package(package)):
		RunLog.info(package + ": installed successfully")
	else:
		RunLog.info(package + ": installed Failed")

	return True

def install_packages_frontend():
	global wdp_install_folder

	RunLog.info("Installing Packages in LoadBalancer Frontend VM")

	# Detect the Distro's -> OpenSUSE/SUSE Linux/Ubuntu and Ubuntu
	if (current_distro == "openSUSE"):
		packages_list = ("mysql-community-server-client","php5", "php5-mysql","apache2-mod_php5","apache2","wget")
	elif (current_distro == "SUSE Linux"):
		packages_list = ("mysql-client","php53", "php53-mysql","apache2-mod_php53","apache2","wget")
	elif (current_distro == "Ubuntu"):
		packages_list = ("mysql-client","php5", "php5-mysql","libapache2-mod-php5","apache2","wget")

	# Detect the Distro's -> Oracle Redhat or Unbreakable / CentOS
	if ((current_distro == "Oracle") or (current_distro == "CentOS")):
		packages_list = ("mysql.x86_64","php", "php-mysql", "httpd" , "wget")

	#Identify the packages list from "packages_list"
	for package in packages_list:
		if(install_package(package)):
			RunLog.info(package + ": installed successfully")
		else:
			RunLog.info(package + ": installation Failed")

	wdp_install_folder = get_apache_document_root()
	if(wdp_install_folder == None):
		RunLog.error("Unable to find wdp_install_folder..")
		RunLog.error("Aborting the installation.")
		end_the_script()

	#Downloading "WordPress" from Web URL
	#wdp_install_folder = get_apache_document_root()
	if(download_url(wdp_downlink, wdp_install_folder)):
		RunLog.info("Wordpress package downloaded successfully")
		Run("echo '"+vm_password+"' | sudo -S tar -xvf "+wdp_install_folder+"/latest.tar.gz -C "+wdp_install_folder)
	else:
		RunLog.info("Wordpress package downloaded failed.")
		return False

	return True

def mysql_secure_install(wdp_db_root_password):
	RunLog.info("Installing mysl_secure_install Package ")
	#spawn command
	child = pexpect.spawn ("/usr/bin/mysql_secure_installation")

	#wait till expected pattern is found
	i = child.expect (['enter for none', pexpect.EOF])
	if (i == 0):
		child.sendline ("")	 #send y
		RunLog.info("'enter for none' command successful\n")

	#wait till expected pattern is found
	try:
		i = child.expect (['\? \[Y\/n\]', pexpect.EOF])
		if (i == 0):
			child.sendline ("Y")	#send y
			RunLog.info("'Set root password' command successful\n"+child.before)
	except:
		RunLog.info("exception:" + str(i))
		return

	for x in range(0, 10):
		#wait till expected pattern is found
		try:
			i = child.expect (['\? \[Y\/n\]', 'password:', pexpect.EOF])
			if (i == 0):
				child.sendline ("Y")	#send y
			elif(i == 1):
				child.sendline (wdp_db_root_password)   #send y
			else:
				break
		except:
			RunLog.info("exception:" + str(i))
			return
	# Check the status of the function for Pass and Fail case

def create_db_wdp(wdp_db_name):
	RunLog.info("Creating DataBase for WordPress ")
	#spawn command
	child = pexpect.spawn ('mysql -uroot -p'+wdp_db_root_password)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ('CREATE DATABASE '+wdp_db_name+";")
		RunLog.info("'CREATE DATABASE' command successful\n"+child.before)
		i = child.expect (['mysql>', pexpect.EOF])
		if (i == 0):
			child.sendline ("show databases;")	  #send y
			RunLog.info("'show databases' command successful\n"+child.before)

		i = child.expect (['mysql>', pexpect.EOF])
		if (i == 0):
			child.sendline ("exit")
		return True

	return False

def create_user_db_wdp(wdp_db_name, wdp_db_hostname, wdp_db_username, wdp_db_password):

	RunLog.info("Creating Database users for WordPress")
	#spawn command
	child = pexpect.spawn ('mysql -uroot -p'+wdp_db_root_password)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ('CREATE USER '+wdp_db_username+"@"+wdp_db_hostname+";") #send y
		RunLog.info("'CREATE USER' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("GRANT ALL PRIVILEGES ON "+wdp_db_name+".* TO '"+wdp_db_username+"'@'"+wdp_db_hostname+"' IDENTIFIED by '"+wdp_db_password+"' WITH GRANT OPTION;")
		RunLog.info("'GRANT ALL PRIVILEGES' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("FLUSH PRIVILEGES;")	#send y
		RunLog.info("'FLUSH PRIVILEGES' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("show databases;")	  #send y
		RunLog.info("'show databases' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("select host,user from mysql.user;")	#send y
		RunLog.info("'select user' command successful\n"+child.before)

	#wait till expected pattern is found
	i = child.expect (['mysql>', pexpect.EOF])
	if (i == 0):
		child.sendline ("exit") #send y
		RunLog.info("'CREATE USER' command successful\n"+child.before)

def DetectDistro():
	RunLog.info("Detecting Distro ")
	output = Run("echo '"+vm_password+"' | sudo -S cat /etc/*-release")
	outputlist = re.split("\n", output)

	# Finding the Distro
	for line in outputlist:
		if (re.match(r'.*Ubuntu.*',line,re.M|re.I) ):
			return'Ubuntu'
		elif (re.match(r'.*SUSE Linux.*',line,re.M|re.I)):
			return 'SUSE Linux'
		elif (re.match(r'.*openSUSE.*',line,re.M|re.I)):
			return 'openSUSE'
		elif (re.match(r'.*CentOS.*',line,re.M|re.I)):
			return 'CentOS'
		elif (re.match(r'.*Oracle.*',line,re.M|re.I)):
			return 'Oracle'

def get_services_status(service):
	RunLog.info("Acquiring the status of services")
	current_status = "unknown"
 	if ((DetectDistro() == 'SUSE Linux') or (DetectDistro() == 'openSUSE')):
		service_command = "/etc/init.d/"
	else:
		service_command = "service "  #space character after service is mandatory here.

	RunLog.info("get service func : " + service)
	output = Run("echo '"+vm_password+"' | sudo -S "+service_command+service+" status")
	outputlist = re.split("\n", output)

	for line in outputlist:
		#start condition
		if (re.match(re.escape(service)+r'.*start\/running', line, re.M|re.I) or \
			re.match(r'.*'+re.escape(service)+r'.*is running.*', line, re.M|re.I) or \
			re.match(r'Starting.*'+re.escape(service)+r'.*OK',line,re.M|re.I) or \
			re.match(r'^Checking for.*running', line, re.M|re.I) or \
			re.match(r'.*active \(running\).*', line, re.M|re.I)):
			RunLog.info(service+": service is running\n"+line)
			current_status = "running"

		if (re.match(re.escape(service)+r'.*Stopped.*',line,re.M|re.I) or \
			re.match(r'.*'+re.escape(service)+r'.*is not running.*', line, re.M|re.I) or \
			re.match(re.escape(service)+r'.*stop\/waiting', line, re.M|re.I) or \
			re.match(r'^Checking for.*unused', line, re.M|re.I) or \
			re.match(r'.*inactive \(dead\).*', line, re.M|re.I)):
			RunLog.info(service+": service is stopped\n"+line)
			current_status = "stopped"
	
	if(current_status == "unknown"):
		output = Run("pgrep "+service+" |wc -l")
		if (int(output) > 0):
			RunLog.info("Found '"+output+"' instances of service: "+service+" running.")
			RunLog.info(service+": service is running\n")
			current_status = "running"
		else:
			RunLog.info("No instances of service: "+service+" are running.")
			RunLog.info(service+": service is not running\n")
			current_status = "stopped"

	return (current_status)

def set_services_status(service, status):
	RunLog.info("Setting service status")
	current_status = "unknown"
	set_status = False

	RunLog.info("service :" + service)
	if ((DetectDistro() == 'SUSE Linux') or (DetectDistro() == 'openSUSE')):
		service_command = "/etc/init.d/"
	else:
		service_command = "service "  #space character after service is mandatory here.

	RunLog.info("service status:"+ status)
	output = Run("echo '"+vm_password+"' | sudo -S "+service_command+service+" "+status)
	current_status = get_services_status(service)
	RunLog.info("current_status -:" + current_status)

	if((current_status == "running") and (status == "restart" or status == "start" )):
		set_status = True
	elif((current_status == "stopped") and (status == "stop")):
		set_status = True
	else:
		RunLog.info("set_services_status failed\nError log: \n" + output)

	return (set_status, current_status)

def disable_selinux():
	RunLog.info("Disabling SELINUX")
	selinuxinfo =  Run ("echo '"+vm_password+"' | sudo -S cat /etc/selinux/config")
	if (selinuxinfo.rfind('SELINUX=disabled') != -1):
		RunLog.info("selinux is already disabled")
	else :
		selinux = Run ("echo '"+vm_password+"' | sudo -S sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config ")
		if (selinuxinfo.rfind('SELINUX=disabled') != -1):
			RunLog.info("selinux is disabled")

def disable_iptables():
	RunLog.info("Disabling IPPTABLES...")
	#Identify the Distro and disable the Firewall
	if (current_distro == 'Ubuntu'):
		ufw = Run ("echo '"+vm_password+"' | sudo -S ufw disable")
		RunLog.info(ufw)
	else:
		Run ("echo '"+vm_password+"' | sudo -S chkconfig iptables off")
		Run ("echo '"+vm_password+"' | sudo -S chkconfig ip6tables off")
	RunLog.info("Disabling IPPTABLES...[done]")

def setup_wordpress():
	RunLog.info("Setup the details of WordPress")

	wdp_install_folder = get_apache_document_root()
	if(wdp_install_folder == None):
		RunLog.error("Unable to find wdp_install_folder..")
		RunLog.error("Aborting the installation.")
		end_the_script()
	else:
		Run("echo '"+vm_password+"' | sudo -S cp "+wdp_install_folder+"wordpress/wp-config-sample.php "+wdp_install_folder+"wordpress/wp-config.php")
		Run("echo '"+vm_password+"' | sudo -S sed -i 's/database_name_here/" + wdp_db_name+ "/' "+wdp_install_folder+"wordpress/wp-config.php")
		Run("echo '"+vm_password+"' | sudo -S sed -i 's/username_here/"+wdp_db_username+"/' "+wdp_install_folder+"wordpress/wp-config.php")
		Run("echo '"+vm_password+"' | sudo -S sed -i 's/password_here/"+wdp_db_password+"/' "+wdp_install_folder+"wordpress/wp-config.php")
		Run("echo '"+vm_password+"' | sudo -S sed -i 's/localhost/"+wdp_db_hostname+"/' "+wdp_install_folder+"wordpress/wp-config.php")

def UpdateRepos():
	RunLog.info("Updating repositories")
	#Repo update for current_distro
	if ((current_distro == "Ubuntu") or (current_distro == "Debian")):
		Run("echo '"+vm_password+"' | sudo -S apt-get update")
	elif ((current_distro == "RedHat") or (current_distro == "Oracle") or (current_distro == 'CentOS')):
		Run("echo '"+vm_password+"' | sudo -S yum -y update")
	elif (current_distro == "openSUSE") or (current_distro == "SUSE Linux"):
		Run("echo '"+vm_password+"' | sudo -S zypper --non-interactive --gpg-auto-import-keys update")
	else:
		RunLog.info("Repo up-gradation failed on:"+ current_distro)
		exit

def setup_wordpress_singleVM():
	RunLog.info("Setup WordPress for SingleVM")
	if (not install_packages_singleVM()):
		RunLog.info("Failed to install packages for singleVM")
		exit

	set_services_status(service_mysqld_name, "start")
	rtrn = get_services_status(service_mysqld_name)
	if (rtrn != "running"):
		RunLog.info("Failed to start mysqld")
		exit

	if (current_distro != 'Ubuntu'):
			mysql_secure_install(wdp_db_root_password)

	# Creating a database from mysql
	create_db_wdp(wdp_db_name)
	# Creating a database from mysql
	create_user_db_wdp(wdp_db_name, wdp_db_hostname, wdp_db_username, wdp_db_password)

	set_services_status(service_httpd_name, "start")
	rtrn = get_services_status(service_httpd_name)

	if (rtrn != "running"):
		RunLog.info("Failed to start :" + service_httpd_name)
		exit

	setup_wordpress()
	RunLog.info( "Restarting services for WordPress")

	set_services_status(service_mysqld_name, "restart")
	rtrn = get_services_status ( service_mysqld_name)
	if (rtrn != "running"):
		exit

	set_services_status(service_httpd_name, "restart")
	rtrn = get_services_status (service_httpd_name)
	if (rtrn != "running"):
		exit

def setup_wordpress_E2ELoadBalance_backend(front_end_users):
	RunLog.info("Setup WordPress for E2ELoadbalancer Backend VM")
	disable_selinux()
	disable_iptables()

	# Installing packages in Backend VM Role
	if (not install_packages_backend()):
		RunLog.info("Failed to install packages for Backend VM Role")
		exit

	set_services_status(service_mysqld_name, "start")
	rtrn = get_services_status(service_mysqld_name)
	if (rtrn != "running"):
		RunLog.info( "Failed to start mysqld")
		exit

	# To make to connection from backend to other IP's ranging from 0.0.0.0
	bind = Run("echo '"+vm_password+"' | sudo -S sed -i 's/\(bind-address.*= \)\(.*\)/\\1 0.0.0.0/' /etc/mysql/my.cnf | grep bind")
	set_services_status(service_mysqld_name, "restart")
	rtrn = get_services_status(service_mysqld_name)
	if (rtrn != "running"):
		RunLog.info("Failed to start mysqld")
		exit

	# Installing the "mysql secure installation" in other Distro's (not in Ubuntu)
	if (current_distro != 'Ubuntu'):
		mysql_secure_install(wdp_db_root_password)

	# Creating database using mysql
	create_db_wdp (wdp_db_name)
	# Creating users to access database from mysql
	#Create_user_db_wdp(wdp_db_name, wdp_db_hostname, wdp_db_username, wdp_db_password)

	for ip in front_end_users:
		create_user_db_wdp(wdp_db_name, ip, wdp_db_username, wdp_db_password)
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig --add mysqld")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig mysqld on")

def setup_wordpress_E2ELoadBalance_frontend():
	global wdp_install_folder
	RunLog.info("Setup WordPress for E2ELoadbalancer Frontend VM")
	disable_selinux()
	disable_iptables()

	# Installing packages in Front-end VM Role's
	if (not install_packages_frontend()):
		RunLog.info("Failed to install packages for Frontend VM Role")
		end_the_script()

	set_services_status(service_httpd_name, "start")
	rtrn = get_services_status(service_httpd_name)

	if (rtrn != "running"):
		RunLog.info("Failed to start :" + service_httpd_name)
		end_the_script()

	wdp_install_folder = get_apache_document_root()
	if(wdp_install_folder == None):
		RunLog.error("Unable to find wdp_install_folder..")
		RunLog.error("Aborting the installation")
		end_the_script()

	setup_wordpress()
	RunLog.info("Restarting services for WordPress")

	set_services_status(service_httpd_name, "restart")
	rtrn = get_services_status (service_httpd_name)
	if (rtrn != "running"):
		exit
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig --add httpd")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig httpd on")
	Run ("echo '"+vm_password+"' | sudo -S /sbin/chkconfig apache2 on")

def update_python_and_install_pexpect():
	RunLog.info("Updating Python Version to install pexpect")
	python_install_commands = (
	"wget --no-check-certificate http://python.org/ftp/python/2.7.2/Python-2.7.2.tgz", \
	"tar -zxvf Python-2.7.2.tgz", \
	"cd Python-2.7.2", \
	"./configure --prefix=/opt/python2.7 --enable-shared", \
	"make", \
	"make altinstall", \
	'echo "/opt/python2.7/lib" >> /etc/ld.so.conf.d/opt-python2.7.conf', \
	"ldconfig", \
	"cd ..", \
	'if [ -f "/opt/python2.7/bin/python2.7" ];then ln -fs /opt/python2.7/bin/python2.7 /usr/bin/python ;fi'
	)

	pexpect_install_commands = ("wget http://kaz.dl.sourceforge.net/project/pexpect/pexpect/Release%202.3/pexpect-2.3.tar.gz", \
	"tar -xvf pexpect-2.3.tar.gz", \
	"cd pexpect-2.3", \
	"python setup.py install")

	pckg_list = ("readline-devel", "openssl-devel", "gmp-devel", "ncurses-devel", "gdbm-devel", "zlib-devel", "expat-devel",\
	"libGL-devel", "tk", "tix", "gcc-c++", "libX11-devel", "glibc-devel", "bzip2", "tar", "tcl-devel", "tk-devel", \
	"pkgconfig", "tix-devel", "bzip2-devel", "sqlite-devel", "autoconf", "db4-devel", "libffi-devel", "valgrind-devel")

	RunLog.info("Installing packages to build python..")
	for pkg in pckg_list:
		install_package(pkg)

	RunLog.info("Installing packages ..[done]")

	RunLog.info("Installing python 2.7.2")
	RunLog.info(exec_multi_cmds_local_sudo(python_install_commands))

	output = Run ("python -V 2>&1")
	if "2.7.2" not in output:
		RunLog.info("Installing python 2.7.2 .. [failed!]\nAborting the script..\n")
		end_the_script()
	else:
		RunLog.info("Installing python 2.7.2 .. [done]")

	RunLog.info("Installing pexpect from source..")
	exec_multi_cmds_local_sudo(pexpect_install_commands)
	RunLog.info("Installing pexpect from source.. [done]")
	RunLog.info("\n\nInvoking the script with new python:....")
	Run("python "+__file__+" "+' '.join(sys.argv[1:]))

def file_get_contents(filename):
	with open(filename) as f:
		return f.read()
		
def get_file_sftp(user_name, password, ip, file_name):
	#spawn command
	child = pexpect.spawn ("sftp "+user_name+"@"+ip)
	child.logfile = open("/tmp/mylog", "w")
	file_sent = False

	for j in range(0,6):
		#wait till expected pattern is found
		i = child.expect (['.assword', ".*>", "yes/no",pexpect.EOF])
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

	return file_get_contents( "/tmp/mylog")
	
def put_file_sftp(user_name, password, ip, file_name):
	RunLog.info("Placing the files using sftp")
	#spawn command
	child = pexpect.spawn ("sftp "+user_name+"@"+ip)
	child.logfile = open("/tmp/mylog", "w")

	for j in range(0,6):
		#wait till expected pattern is found
		i = child.expect (['.assword', ".*>", "yes/no",pexpect.EOF])
		if (i == 0):
			child.sendline (password)
			RunLog.info("Password entered")
		elif (i == 2):
			child.sendline ("yes")
			RunLog.info("yes sent")
		elif (i == 1):
			child.sendline ("put "+file_name)
			RunLog.info("put file succesful")
			child.sendline ("exit")
			break
	return file_get_contents( "/tmp/mylog")

def exec_cmd_remote_ssh(user_name, password, ip, command):
	RunLog.info("Executing commands in remote ssh")
	#spawn command
	child = pexpect.spawn ("ssh -t "+user_name+"@"+ip+" "+command)
	child.logfile = open("/tmp/"+ip+"-ssh.log", "w")

	for j in range(0,6):
		#wait till expected pattern is found
		child.timeout=9000
		i = child.expect (['.assword', "yes/no",pexpect.EOF])
		if (i == 0):
			child.sendline (password)
			RunLog.info("Password entered")
		elif (i == 1):
			child.sendline ("yes")
			RunLog.info("yes sent")
		else:
			break
	return file_get_contents("/tmp/"+ip+"-ssh.log")

def verify_wdp_instllation():
	if (sys.argv[1] == 'loadbalancer_setup'):
		ips = front_endVM_ips
		time.sleep(200)
	elif (sys.argv[1] == "singleVM_setup"):
		ips = ["127.0.0.1"]
	else:
		return 1

	Run("mkdir /tmp/verify_wdp/")
	for ip in ips:
		wdp_url = "http://"+ip+"/wordpress/wp-admin/install.php"
		Run("wget -t 2 -T 3 "+wdp_url+" -O /tmp/verify_wdp/"+ip+".html")
	output = Run("grep -irun 'Install wordpress' /tmp/verify_wdp/ | wc -l")
	Run("rm -rf  /tmp/verify_wdp/")
	output = output.rstrip('\n')

	if( int(output) == len(ips)):
		RunLog.info("WDP_INSTALL_PASS")
		Run("echo 'WDP_INSTALL_PASS' > wdp_test.txt")
		return 0
	else:
		RunLog.info("WDP_INSTALL_FAIL")
		Run("echo 'WDP_INSTALL_FAIL' > wdp_test.txt")
		return 1

def collect_logs():
	Run("mkdir logs")
	Run("cp -f /tmp/*.log logs/")
	if (sys.argv[1] == 'loadbalancer_setup'):
		for ip in front_endVM_ips:
			exec_cmd_remote_ssh(vm_username, vm_password, ip, "mv Runtime.log "+ip+"-Runtime.log")
			get_file_sftp(vm_username, vm_password, ip, ip+"-Runtime.log")
	Run("cp -f *.log logs/")
	Run("cp -f wdp_test.txt logs/")
	Run("tar -czvf logs.tar.gz logs/")
	
def get_username_password_from_xml():
	global vm_username
	global vm_password
#TODO add file existance check before accessing it.
	if(not os.path.isfile("wordpress_install.XML")):
		RunLog.error("File not found wordpress_install.XML")
		end_the_script()
	output = file_get_contents("wordpress_install.XML")
	outputlist = re.split("\n", output)

	for line in outputlist:
		if "</username>" in line:
			matchObj = re.match( r'.*<username>(.*)</username>', line, re.M|re.I)
			vm_username = matchObj.group(1)
		elif "</password>" in line:
			matchObj = re.match( r'.*<password>(.*)</password>', line, re.M|re.I)
			vm_password = matchObj.group(1)

def show_usage():
	RunLog.info("Show Usage...")
	RunLog.info("Error: Invalid usage")
	RunLog.info("Usage: \"python "+__file__+" singleVM_setup\" for single VM wordpresssetup")
	RunLog.info("Usage: \"python "+__file__+" loadbalancer_setup\" for locadbalanced wordpress-setup")
	RunLog.info("Usage: \"python "+__file__+" frontend_setup <back end vm ip>\" frontend setup for locadbalanced wordpress setup")
	end_the_script()

def end_the_script():
	print file_get_contents("/home/"+vm_username+"/Runtime.log")
	exit()

def main():
	RunLog.info("Main Function to implement E2ESingle or E2ELoadBalance Setup")
	ip = "127.0.0.1"
	global wdp_db_hostname
	global front_endVM_ips

	front_endVM_username	= vm_username
	front_endVM_password	= vm_password
	file_name	   = __file__

	if len(sys.argv) > 1 :
		if sys.argv[1] == 'loadbalancer_setup':
			if len(sys.argv) == 2 :
				output = file_get_contents("wordpress_install.XML")
				outputlist = re.split("\n", output)

				for line in outputlist:
					if "</back_endVM_ip>" in line:
						matchObj = re.match( r'.*<back_endVM_ip>(.*)</back_endVM_ip>', line, re.M|re.I)
						back_endVM_ip = matchObj.group(1)
						wdp_db_hostname = back_endVM_ip

					elif "</front_endVM_ips>" in line:
						matchObj = re.match(r'.*<front_endVM_ips>(.*)</front_endVM_ips>', line, re.M|re.I)
						front_endVM_ips = str.split(matchObj.group(1))

						RunLog.info("Starting loadbalancer_setup")
						RunLog.info("Starting backend VM setup")
						setup_wordpress_E2ELoadBalance_backend(front_endVM_ips)
						frontend_count = 1
						for ip in front_endVM_ips:
							RunLog.info("**********************************************************")
							RunLog.info("\nConfiguring frontend"+str(frontend_count)+" at "+ip+":\n")
							# TODO FIX TCP alive on Servers and restart the 
							RunLog.info("Copying "+__file__+" to "+ ip)							
							RunLog.info(put_file_sftp(front_endVM_username, front_endVM_password, ip, __file__))
							RunLog.info("Copying "+"azuremodules.py"+" to "+ ip)
							RunLog.info(put_file_sftp(front_endVM_username, front_endVM_password, ip, "azuremodules.py"))
							RunLog.info("Copying wordpress_install.XML to "+ ip)
							RunLog.info(put_file_sftp(front_endVM_username, front_endVM_password, ip, "wordpress_install.XML"))
							RunLog.info("Starting frontend VM setup on "+ ip)
							RunLog.info(exec_cmd_remote_ssh(front_endVM_username, front_endVM_password, ip, "python "+file_name+" frontend_setup "+ back_endVM_ip))
							frontend_count = frontend_count+1
			else:
				show_usage()
		elif sys.argv[1] == 'frontend_setup':
			if len(sys.argv) == 3:
				wdp_db_hostname = sys.argv[2]
				setup_wordpress_E2ELoadBalance_frontend()
				#Reboot the Frontend1,2,3
				RunLog.info( "Rebooting the frontend....\n")
				if (current_distro != "openSUSE"):
					RunLog.info( exec_multi_cmds_local_sudo(["reboot"]))
				else:
					RunLog.info( exec_multi_cmds_local_sudo(["/sbin/reboot"]))
			elif len(sys.argv) < 3:
				RunLog.info("Back end IP missing")
				show_usage()
			else:
				show_usage()
		elif sys.argv[1] == "singleVM_setup":
			if len(sys.argv) == 2 :
				RunLog.info("Starting single VM setup")
				setup_wordpress_singleVM()
			else:
				show_usage()
		else:
			show_usage()
	else:
		show_usage()

# Code execution Start from here
get_username_password_from_xml()
set_variables_OS_dependent()
UpdateRepos()

#check for availability of pexpect module
try:
	imp.find_module('pexpect')
	import pexpect
except ImportError:
	RunLog.info("Pexpect module import failed")
	RunLog.info("Unable to found pexpect module")
	RunLog.info("Trying to install")
	RunLog.info("pexpect_pkg_name:" + pexpect_pkg_name)
	if(not install_package(pexpect_pkg_name)):
		RunLog.info("pexpect module could not be installed")
		RunLog.info("Installing pexpect from source..")
		RunLog.info("Updating the Python Version to install pexpect module")
		update_python_and_install_pexpect()
		RunLog.info("\n\nInvoking the script with new python:....")
		Run("python "+__file__+" "+' '.join(sys.argv[1:]))
		end_the_script()

import pexpect
RunLog.info("Executing Main Function...")
main()
result = verify_wdp_instllation()
collect_logs()
end_the_script()
#We should be able to see wordpress install page in the browser.

