#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vms', help='VM Hostnames and DIPs.', required=True)
args = parser.parse_args()

HostnameDIP = args.vms



#SAMPLE INPUT FOR --vms 
#HostnameDIP = 'ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-0-role-0:192.168.4.196^ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-0-role-1:192.168.4.132^ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-1-role-0:192.168.4.133^ICA-VNETVM-Ubuntu1210PL-4-16-2013-1-2-1-role-1:192.168.4.197'


#SETTING THE GLOBAL PARAMS..
SetVnetGlobalParameters()

#CONFIGURIG DNS SERVER CONFIGURATIONS FILES..
AddICAVMsToDnsServer(HostnameDIP)

#RESTARTING BIND9 SERVICE..
output = JustRun('service bind9 restart')
print(output)
