#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko

        #for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-u', '--user', help='usename', required=True)
parser.add_argument('-p', '--password', help='Password.',required=True )
parser.add_argument('-c', '--command', help='command', required=True)
parser.add_argument('-s', '--host', help='host address', required=True)
parser.add_argument('-P', '--port', help='Port', required=True, type=int )

#parser.add_argument('-m', '--print_mss', help='print TCP maximum segment size (MTU - TCP/IP header) ', choices=['yes', 'no'])
#parser.add_argument('-M', '--mss', help='set TCP maximum segment size (MTU - 40 bytes)', type = int)
#parser.add_argument('-i', '--interval', help='specifies frequency of the output to be displyed on screen', type= int)
#parser.add_argument('-l', '--length', help='length of buffer to read or write (default 8 KB)', type= int)
#parser.add_argument('-P', '--parallel', help='number of parallel client threads to run', type= int)
#parser.add_argument('-t', '--time', help='duration for which test should be run', required=True)
#parser.add_argument('-p', '--port', help='specifies which port should be used', required=True, type= int)
args = parser.parse_args()
                #if no value specified then stop
command = args.command
user = args.user
passwd =  args.password
host = args.host
passwd = passwd
hostport = args.port

ssh    = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, port = hostport, username=user, password=passwd)
stdin, stdout, stderr = ssh.exec_command(command)
stdin.write(passwd)
stdin.flush()
outResult =  stdout.read()
outError = stderr.read()
#print (outResult)
#print (outError)
ResultCommand = "echo Result = " + outResult
#ErrorCommand = "echo Errpr = " + outError
#ResultCommand = ResultCommand.rstrip('\n')
#ErrorCommand = ErrorCommand.rstrip('\n')
#print ResultCommand
#print ErrorCommand
Run(ResultCommand)
#Run(ErrorCommand)
ssh.close()
