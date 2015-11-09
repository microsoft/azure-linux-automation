#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko
parser = argparse.ArgumentParser()
parser.add_argument('-D', '--vnetDomain_db_filepath', help='VNET Domain db filepath', required=True)
parser.add_argument('-r', '--vnetDomain_rev_filepath', help='VNET rev filepath',required=True)
args = parser.parse_args()
vnetDomain_db_filepath =  str(args.vnetDomain_db_filepath)
vnetDomain_rev_filepath = str(args.vnetDomain_rev_filepath)
vnetDomain=(vnetDomain_db_filepath.split("/"))[len((vnetDomain_db_filepath.split("/")))-1].replace(".db","")
RemoveICAVMsFromDBfile(vnetDomain_db_filepath)
RemoveICAVMsFromREVfile(vnetDomain_rev_filepath)
