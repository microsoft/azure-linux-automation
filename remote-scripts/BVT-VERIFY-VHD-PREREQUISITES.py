#!/usr/bin/python

from azuremodules import *

import argparse
import sys
 #for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-d', '--distro', help='Please mention which distro you are testing', required=True, type = str)

args = parser.parse_args()
distro = args.distro

def verify_default_targetpw(distro):
        RunLog.info("Checking Defaults targetpw is commented or not..")
        sudoers_out = Run("cat /etc/sudoers")
        if "Defaults targetpw" in sudoers_out:
                if "#Defaults targetpw" in sudoers_out:
                        print(distro+"_TEST_SUDOERS_VERIFICATION_SUCCESS")
                        RunLog.info("Defaults targetpw is commented")
			return True
                else:
                        RunLog.error("Defaults targetpw is present in /etc sudoers but it is not commented.")
                        print(distro+"_TEST_SUDOERS_VERIFICATION_FAIL")
			return False
        else:
                RunLog.info("Defaults targetpw is not present in /etc/sudoers")
                print(distro+"_TEST_SUDOERS_VERIFICATION_SUCCESS")
		return True

def verify_grub(distro):
        import os.path
	RunLog.info("Checking console=ttyS0 earlyprintk=ttyS0 rootdelay=300..")
	if distro == "UBUNTU" or distro == "SUSE":
		grub_out = Run("cat /etc/default/grub")
	if distro == "CENTOS" or distro == "ORACLELINUX" or distro == "REDHAT" or distro == "SLES":
		if os.path.isfile("/boot/grub2/grub.cfg"):
			RunLog.info("Getting Contents of /boot/grub2/grub.cfg")
			grub_out = Run("cat /boot/grub2/grub.cfg")
		elif os.path.isfile("/boot/grub/menu.lst"):
			RunLog.info("Getting Contents of /boot/grub/menu.lst")
                        grub_out = Run("cat /boot/grub/menu.lst")
		else:
			RunLog.error("Unable to locate grub file")
			print(distro+"_TEST_GRUB_VERIFICATION_FAIL")
			return False
        if "console=ttyS0" in grub_out and "earlyprintk=ttyS0" in grub_out and "rootdelay=300" in grub_out and "libata.atapi_enabled=0" not in grub_out and "reserve=0x1f0,0x8" not in grub_out:
		if distro == "CENTOS" or distro == "ORACLELINUX":
			if "numa=off" in grub_out:
       	        		print(distro+"_TEST_GRUB_VERIFICATION_SUCCESS")
			else : 
				RunLog.error("numa=off not present in etc/default/grub")
				print(distro+"_TEST_GRUB_VERIFICATION_FAIL")
		else:
			print(distro+"_TEST_GRUB_VERIFICATION_SUCCESS")
		return True
        else:
       	        print(distro+"_TEST_GRUB_VERIFICATION_FAIL")
           	if "console=ttyS0" not in grub_out:
                        RunLog.error("console=ttyS0 not present")
                if "earlyprintk=ttyS0" not in grub_out:
                        RunLog.error("earlyprintk=ttyS0 not present")
                if "rootdelay=300" not in grub_out:
                        RunLog.error("rootdelay=300 not present")
		if "libata.atapi_enabled=0" in grub_out:
			RunLog.error("libata.atapi_enabled=0 is present")
		if "reserve=0x1f0,0x8" in grub_out:
                        RunLog.error("reserve=0x1f0,0x8 is present")
		return False

def verify_network_manager(distro):
	RunLog.info("Verifying that network manager is not installed")
	if distro == "CENTOS" or distro == "ORACLELINUX" or distro == "REDHAT":
		n_out = Run ("rpm -q NetworkManager")
		if "is not installed" in n_out:
			RunLog.info("Network Manager is not installed")
			print(distro+"_TEST_NETWORK_MANAGER_NOT_INSTALLED")
			return True
		else:
                        RunLog.error("Network Manager is installed")
                        print(distro+"_TEST_NETWORK_MANAGER_INSTALLED")
			return False

def verify_network_file_in_sysconfig(distro):
	import os.path
	RunLog.info("Checking if network file exists in /etc/sysconfig")
	if distro == "CENTOS" or distro == "ORACLELINUX" or distro == "REDHAT":
		if os.path.isfile("/etc/sysconfig/network"):
			RunLog.info("File Exists.")
			n_out = Run("cat /etc/sysconfig/network")
			if "networking=yes".upper() in n_out.upper():
				RunLog.info("NETWORKING=yes present in network file")
				print(distro+"_TEST_NETWORK_FILE_SUCCESS")
				return True
			else:
				RunLog.error("NETWORKING=yes not present in network file")
                                print(distro+"_TEST_NETWORK_FILE_ERROR")
				return False
		else:
			RunLog.error("File not present")
			print(distro+"_TEST_NETWORK_FILE_ERROR")
			return False

def verify_ifcfg_eth0(distro):
	RunLog.info("Verifying contents of ifcfg-eth0 file")
	if distro == "CENTOS" or distro == "ORACLELINUX" or distro == "REDHAT":
		i_out = Run("cat /etc/sysconfig/network-scripts/ifcfg-eth0")
		#if "DEVICE=eth0" in i_out and "ONBOOT=yes" in i_out and "BOOTPROTO=dhcp" in i_out and "DHCP=yes" in i_out:
		if "DEVICE=eth0" in i_out and "ONBOOT=yes" in i_out and "BOOTPROTO=dhcp" in i_out  :
			RunLog.info("all required parameters exists.")
			print(distro+"_TEST_IFCFG_ETH0_FILE_SUCCESS")
			return True
		else:
			if "DEVICE=eth0" not in i_out:
				RunLog.error("DEVICE=eth0 not present in ifcfg-eth0")
			if "ONBOOT=yes" not in i_out:
				RunLog.error("ONBOOT=yes not present in ifcfg-eth0")
			if "BOOTPROTO=dhcp" not in i_out:
				RunLog.error("BOOTPROTO=dhcp not present in ifcfg-eth0")
			#if "DHCP=yes" not in i_out:
			#	RunLog.error("DHCP=yes not present in ifcfg-eth0")
			print(distro+"_TEST_IFCFG_ETH0_FILE_ERROR")
			return False

def verify_udev_rules(distro):
	import os.path
	RunLog.info("Verifying if udev rules are moved to /var/lib/waagent/")
	if distro == "CENTOS" or distro == "ORACLELINUX" or distro == "REDHAT":
		if not os.path.isfile("/lib/udev/rules.d/75-persistent-net-generator.rules") and not os.path.isfile("/etc/udev/rules.d/70-persistent-net.rules"):
			RunLog.info("rules are moved.")
			print(distro+"_TEST_UDEV_RULES_SUCCESS")
			return True
		else:
			if os.path.isfile("/lib/udev/rules.d/75-persistent-net-generator.rules"):
				RunLog.error("/lib/udev/rules.d/75-persistent-net-generator.rules file present")
                        if os.path.isfile("/etc/udev/rules.d/70-persistent-net.rules"):
                                RunLog.error("/etc/udev/rules.d/70-persistent-net.rules file present")
			print(distro+"_TEST_UDEV_RULES_ERROR")
			return False

if distro == "UBUNTU":
	RunLog.info("DISTRO PROVIDED : "+distro)
	#Test 1 : make sure that hv-kvp-daemon-init is installed
	RunLog.info("Checking if hv-kvp-daemon-init is installed or not..")
	#kvp_install_status = Run("dpkg -s hv-kvp-daemon-init")
	kvp_install_status = Run("pgrep -lf hv_kvp_daemon")
	matchCount = 0
	if "hv_kvp_daemon" in kvp_install_status:
		matchCount = matchCount + 1
	if matchCount == 1:
		print(distro+"_TEST_KVP_INSTALLED")
	else:
		print(distro+"_TEST_KVP_NOT_INSTALLED")

	#Test 2 : Make sure that repositories are installed.
	RunLog.info("Checking if repositories are installed or not..")
	repository_out = Run("apt-get update")
	if "security.ubuntu.com" in repository_out and "azure.archive.ubuntu.com" in repository_out and "Hit" in repository_out:
		print(distro+"_TEST_REPOSITORIES_AVAILABLE")
	else:
		print(distro+"_TEST_REPOSITORIES_ERROR")

	#Test 3 : Make sure to have console=ttyS0 earlyprintk=ttyS0 rootdelay=300 in /etc/default/grub.
	result = verify_grub(distro)

	#Test 4 : Make sure that default targetpw is commented in /etc/sudoers file.
        result = verify_default_targetpw(distro)

if distro == "SUSE":
	#Make sure that distro contains Cloud specific repositories
	RunLog.info("Verifying Cloud specific repositories")
	r_out = Run("zypper lr")
	if "Cloud:Tools_" in r_out and "_OSS" in r_out and "_Updates" in r_out:
		RunLog.info("All expected repositories are present")
		r_out_words = r_out.split(" ")
		yesCount = 0
		for eachWord in r_out_words:
			if eachWord == "Yes":
				yesCount = yesCount + 1
		if yesCount == 6:
			RunLog.info("All expected repositories are enabled and refreshed")
			print(distro+"_TEST_REPOSITORIES_AVAILABLE")
		else:
			RunLog.error("One or more expected repositories are not present")
			print(distro+"_TEST_REPOSITORIES_ERROR")
	else:
		RunLog.error("One or more expected repositories are not enabled/refreshed.")
		print(distro+"_TEST_REPOSITORIES_ERROR")
	
	#Verify Grub
	result = verify_grub(distro)
	#Test : Make sure that default targetpw is commented in /etc/sudoers file.
        result = verify_default_targetpw(distro)

if distro == "CENTOS":
	#Test 1 : Make sure Network Manager is not installed
	result = verify_network_manager(distro)
	result = verify_network_file_in_sysconfig(distro)
	result = verify_ifcfg_eth0(distro)
	result = verify_udev_rules(distro)
	#Verify repositories
	r_out = Run("yum repolist")
	if "base" in r_out and "updates" in r_out:
		RunLog.info("Expected repositories are present")
		print(distro+"_TEST_REPOSITORIES_AVAILABLE")
	else:
		if "base" not in r_out:
			RunLog.error("Base repository not present")
		if "updates" not in r_out:
			RunLog.error("Updates repository not present") 
		print(distro+"_TEST_REPOSITORIES_ERROR")
	#Verify etc/yum.conf
	y_out = Run("cat /etc/yum.conf")
        if "http_caching=packages" in y_out:
                RunLog.info("http_caching=packages present in /etc/yum.conf")
                print(distro+"_TEST_YUM_CONF_SUCCESS")
        else:
		RunLog.error("http_caching=packages not present in /etc/yum.conf")
                print(distro+"_TEST_YUM_CONF_ERROR")
	result = verify_grub(distro)

if distro == "REDHAT":
        #Test 1 : Make sure Network Manager is not installed
        result = verify_network_manager(distro)
        result = verify_network_file_in_sysconfig(distro)
        result = verify_ifcfg_eth0(distro)
        result = verify_udev_rules(distro)
        #Verify repositories
        r_out = Run("yum repolist")
        if "base" in r_out and "updates" in r_out:
                RunLog.info("Expected repositories are present")
                print(distro+"_TEST_REPOSITORIES_AVAILABLE")
        else:
                if "base" not in r_out:
                        RunLog.error("Base repository not present")
                if "updates" not in r_out:
                        RunLog.error("Updates repository not present")
                print(distro+"_TEST_REPOSITORIES_ERROR")
        #Verify etc/yum.conf
        y_out = Run("cat /etc/yum.conf")
        if "http_caching=packages" in y_out:
                RunLog.info("http_caching=packages present in /etc/yum.conf")
                print(distro+"_TEST_YUM_CONF_SUCCESS")
        else:
                RunLog.error("http_caching=packages not present in /etc/yum.conf")
                print(distro+"_TEST_YUM_CONF_ERROR")
        result = verify_grub(distro)

if distro == "ORACLELINUX":
        #Test 1 : Make sure Network Manager is not installed
        result = verify_network_manager(distro)
        result = verify_network_file_in_sysconfig(distro)
        result = verify_ifcfg_eth0(distro)
        result = verify_udev_rules(distro)
        #Verify repositories
        r_out = Run("yum repolist")
        if "base" in r_out and "updates" in r_out:
                RunLog.info("Expected repositories are present")
                print(distro+"_TEST_REPOSITORIES_AVAILABLE")
        else:
                if "base" not in r_out:
                        RunLog.error("Base repository not present")
                if "updates" not in r_out:
                        RunLog.error("Updates repository not present")
                print(distro+"_TEST_REPOSITORIES_ERROR")
        #Verify etc/yum.conf
        y_out = Run("cat /etc/yum.conf")
        if "http_caching=packages" in y_out:
                RunLog.info("http_caching=packages present in /etc/yum.conf")
                print(distro+"_TEST_YUM_CONF_SUCCESS")
        else:
                RunLog.error("http_caching=packages not present in /etc/yum.conf")
                print(distro+"_TEST_YUM_CONF_ERROR")
        result = verify_grub(distro)

if distro == "SLES":
	#Verify Repositories..
	r_out = Run("zypper lr")
        if "SUSE_Linux_Enterprise_Server" in r_out and "Pool" in r_out and "Updates" in r_out:
                RunLog.info("All expected repositories are present")
                RunLog.info("All expected repositories are enabled and refreshed")
                print(distro+"_TEST_REPOSITORIES_AVAILABLE")
        else:
                RunLog.error("One or more expected repositories are not present")
                print(distro+"_TEST_REPOSITORIES_ERROR")
	#Verify Grub
	result = verify_grub(distro)
	#Verify sudoers file
	result = verify_default_targetpw(distro)
	#Vefiry : It is recommended that you set /etc/sysconfig/network/dhcp or equivalent from DHCLIENT_SET_HOSTNAME="yes" to DHCLIENT_SET_HOSTNAME="no"
	RunLog.info('Checking if DHCLIENT_SET_HOSTNAME="no" present in /etc/sysconfig/network/dhcp')
	d_out = Run("cat /etc/sysconfig/network/dhcp")
	if 'DHCLIENT_SET_HOSTNAME="no"' in d_out:
		RunLog.info('DHCLIENT_SET_HOSTNAME="no" present in /etc/sysconfig/network/dhcp')
		print(distro+"_TEST_DHCLIENT_SET_HOSTNAME_IS_NO_SUCCESS")
	else:
		RunLog.error('DHCLIENT_SET_HOSTNAME="no" not present in /etc/sysconfig/network/dhcp')
		print(distro+"_TEST_DHCLIENT_SET_HOSTNAME_IS_NO_FAIL")
