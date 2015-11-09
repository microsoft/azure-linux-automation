#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko
parser = argparse.ArgumentParser()
parser.add_argument('-D', '--vnetDomain_db_filepath', help='VNET Domain db filepath', required=True)
parser.add_argument('-r', '--vnetDomain_rev_filepath', help='VNET rev filepath',required=True)
parser.add_argument('-v', '--HostnameDIP', help='hosts filepath',required = True)
args = parser.parse_args()
vnetDomain_db_filepath =  str(args.vnetDomain_db_filepath)
vnetDomain_rev_filepath = str(args.vnetDomain_rev_filepath)
HostnameDIP=str(args.HostnameDIP)
vnetDomain=(vnetDomain_db_filepath.split("/"))[len((vnetDomain_db_filepath.split("/")))-1].replace(".db","")
#SAMPLE INPUT FOR --vms
#HostnameDIP = 'ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-0-role-0:192.168.4.196^ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-0-role-1:192.168.4.132^ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-1-role-0:192.168.4.133^ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-1-role-1:192.168.4.197'
#SETTING THE GLOBAL PARAMS..
#SetVnetGlobalParameters()
#CONFIGURIG DNS SERVER CONFIGURATIONS FILES..
DNSServerStatus = AddICAVMsToDnsServer(HostnameDIP,vnetDomain_db_filepath,vnetDomain_rev_filepath)
#RESTARTING BIND9 SERVICE..
output = JustRun('service bind9 restart')
if DNSServerStatus == 0:
        print("CONFIGURATION_SUCCESSFUL")
else:
        print("CONFIGURATION_FAILED")