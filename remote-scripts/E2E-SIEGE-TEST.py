#!/usr/bin/python
import re
import time
import imp
import sys
import argparse
import os
import linecache

from azuremodules import *

parser = argparse.ArgumentParser()

parser.add_argument('-u', '--user', help='specifies user to login', required=True, type= str )
parser.add_argument('-p', '--password', help='specifies which password should be used to login', required=True, type= str)
parser.add_argument('-l', '--url', help='Datrader scenario url for siege test', required=True, type= str )
parser.add_argument('-t', '--siegetime', help='time for siege test', required=True, type= str )
parser.add_argument('-n', '--numofusers', help='number of users for siege test', required=True, type= str )

args = parser.parse_args()
vm_username    = args.user
vm_password    = args.password
daytrader_scenario_url = args.url
siegetime= args.siegetime
numofusers = args.numofusers

current_distro="unknown"
distro_version="unknown"


def EndOfTheScript():	
	print FileGetContents("/home/"+vm_username+"/Runtime.log")
	exit()
	
def CollectLogs():
	ExecMultiCmdsLocalSudo(["mkdir logs","cp -f /tmp/*.log logs/","cp -f *.txt logs/","tar -czvf logs.tar.gz logs/"])
	
def SiegeTest():
    if (current_distro == "centos" or current_distro == "rhel" or current_distro == "oracle" or current_distro == "ol"):
        ExecMultiCmdsLocalSudo(["yum update -y ","yum install -y tar wget gcc make"])
        Run("echo '"+vm_password+"' | sudo -S rpm -ivh siege*.rpm")
    elif(current_distro == "openSUSE" or current_distro == "sles"):
        ExecMultiCmdsLocalSudo(["zypper update -y ","zypper install -y gcc make"])
        Run("echo '"+vm_password+"' | sudo -S rpm -ivh siege*.rpm")
    elif(current_distro == "ubuntu"):
        ExecMultiCmdsLocalSudo(["apt-get update -y","apt-get install -y gcc make siege"])
        siegeinfo = Run("echo '"+vm_password+"' | sudo -S siege -V 2>&1")
        if((siegeinfo.rfind("SIEGE ") != -1) and (siegeinfo.rfind("Copyright ") != -1)):
			RunLog.info("Siege tool Available ..")
        else:
			Run("echo '"+vm_password+"' | sudo -S dpkg -i siege*.deb")
    else:
        RunLog.error( "\ndetected distro not in the list and for more details check logs...")
    siegeinfo = Run("echo '"+vm_password+"' | sudo -S siege -V 2>&1")
  
    if((siegeinfo.rfind("SIEGE ") != -1) and (siegeinfo.rfind("Copyright ") != -1)):
        RunLog.info("Siege Setup Completed Successfully")
        #Siege test start here..
        command = "siege "+ daytrader_scenario_url +" -t"+siegetime+" -c"+numofusers+" > SiegeConsoleOutput.txt 2>&1"  
        RunLog.info( "fcmd:'" +command+"'")
        Run("echo SIEGE_TEST_STARTED > siegeteststatus.txt")
        Run(command)
        RunLog.info("siege fininshed")
        RunLog.info("siege fininshed >> siegeteststatus.txt")
    else:
        RunLog.info("Siege Setup Failed")
        EndOfTheScript()

#Test start here
[current_distro, distro_version] = DetectDistro()
SiegeTest()
CollectLogs()
EndOfTheScript()