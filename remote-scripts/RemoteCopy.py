#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko
import azuremodules

parser = argparse.ArgumentParser()

parser.add_argument('-c', '--serverip', help='specifies server VIP of server name', required=True)
parser.add_argument('-m', '--mode', help='switch : specify "upload" or "download" (case sensitive)', choices=['upload', 'download'] )
parser.add_argument('-u', '--username', help='Remote host username', required=True)
parser.add_argument('-p', '--password', help='Remote host password', required=True)
parser.add_argument('-P', '--port', help='Remote host SSH port', required=True, type=int)
parser.add_argument('-l', '--localLocation', help='use with Download switch')
parser.add_argument('-r', '--remoteLocation', help='use with upload switch')
parser.add_argument('-f', '--files', help='mention the complete path of files you want to download or upload. Separate multiple files with (,) comma!')

args = parser.parse_args()

#SetVnetGlobalParameters()

hostIP = args.serverip
hostPassword = args.password
hostUsername = args.username
hostPort = int(args.port)
filesNames = args.files
localLocation = args.localLocation
remoteLocation = args.remoteLocation
copyMode = args.mode

if copyMode == 'upload':
    RemoteUpload(hostIP, hostPassword, hostUsername, hostPort, filesNames, remoteLocation)
if copyMode == 'download':
    RemoteDownload(hostIP, hostPassword, hostUsername, hostPort, filesNames, localLocation)



