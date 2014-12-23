#!/usr/bin/python

##########################################
#THIS SCRIPT INITIATES FIO TEST IN BACKGROUND AND RETURNS CONTROL FROM LINUX TO POWERSHELL.
##########################################

from azuremodules import *

import argparse
import sys
 #for error checking
parser = argparse.ArgumentParser()
parser.add_argument('-f', '--fiofile', help='switch : starts the server in udp data packets listening mode.', required=True )
args = parser.parse_args()
#if no value specified then stop
command = 'fio ' + str(args.fiofile)
finalCommand = 'nohup ' + command + ' > FioConsoleOutput.log &'
Run(finalCommand)