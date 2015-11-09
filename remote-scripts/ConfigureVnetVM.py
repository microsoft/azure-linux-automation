#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko
import azuremodules
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--dns_server_ip', help='DNS server IP address',required=True)
parser.add_argument('-D', '--vnetDomain_db_filepath', help='VNET Domain db filepath', required=True)
parser.add_argument('-R', '--resolv_conf_filepath', help='resolv.conf filepath', required=True)
parser.add_argument('-H', '--hosts_filepath', help='hosts filepath',required = True)
args = parser.parse_args()
vnetDomain_db_filepath =  str(args.vnetDomain_db_filepath)
dns_server_ip = str(args.dns_server_ip)
resolv_conf_filepath = str(args.resolv_conf_filepath)
hosts_filepath = str(args.hosts_filepath)
vnetDomain=(vnetDomain_db_filepath.split("/"))[len((vnetDomain_db_filepath.split("/")))-1].replace(".db","")
#SetVnetGlobalParameters()
resolvConfFileStatus = ConfigureResolvConf(resolv_conf_filepath,dns_server_ip,vnetDomain)
hostFileStatus = ConfigureHostsFile(hosts_filepath)

if resolvConfFileStatus == 0 and hostFileStatus == 0:
	print("CONFIGURATION_SUCCESSFUL")
else:
	print("CONFIGURATOIN_FAILED")
