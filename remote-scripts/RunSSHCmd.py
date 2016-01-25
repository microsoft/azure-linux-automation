#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko

py_ver_str = sys.version

parser = argparse.ArgumentParser()

parser.add_argument('-u', '--user', help='usename', required=True)
parser.add_argument('-p', '--password', help='Password.',required=True )
parser.add_argument('-c', '--command', help='command', required=True)
parser.add_argument('-s', '--host', help='host address', required=True)
parser.add_argument('-P', '--port', help='Port', required=True, type=int )
parser.add_argument('-o', '--sudo', help='Run Command with sudo privileges..', choices=['yes', 'no'], default='no')
args = parser.parse_args()

isSudo = args.sudo
command = args.command
user = args.user
passwd =  args.password
host = args.host
hostport = args.port
isConnectedFile = open("isConnected.txt", "w")
#command = command + " && exitCode=$?" + ' && echo "ExitCooie : $exitCode"'
ssh  = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect(host, port = hostport, username=user, password=passwd)
    isConnectedFile.writelines("True\n")
    outputFile = open("RunSSHCmd-out.txt", "w+")
    ErrorFile = open("RunSSHCmd-err.txt", "w+")
    if isSudo == 'no':
        outputFile.writelines("Executing Command : %s \nOutputStart\n" %command )
        ErrorFile.writelines("Executing Command : %s \nErrorStart\n" %command )
        print("Executing : %s" %command )
        stdin, stdout, stderr = ssh.exec_command(command)
    if isSudo == 'yes':
        sudoCommand = 'echo "%s" | sudo -S %s' % (passwd, command)
        outputFile.writelines("Executing Command : %s \nOutputStart\n" %sudoCommand )
        ErrorFile.writelines("Executing Command : %s \nErrorStart\n" %sudoCommand )
        stdin, stdout, stderr = ssh.exec_command(sudoCommand)
#        stdin, stdout, stderr = ssh.exec_command(command)
    stdin.write(passwd)
    stdin.flush()
    outResult =  stdout.read()
    if py_ver_str[0] == '3':
        outResult = outResult.decode('utf-8')
    outError = stderr.read()
    outputFile.writelines(outResult)
    exitCode =  stdout.channel.recv_exit_status()
    print("OutputStart")
    print(outResult)
    print("OutputEnd")
    print("ErrorStart")
    print(outError)
    print("ErrorEnd")
    print("ExitCode : %s" %  exitCode)
    outputFile.writelines("OutputEnd\nExitCode : %s\n" %exitCode)
    outputFile.close()
    if outError == "":
        ErrorFile.writelines("NoError\n")
    else:
        ErrorFile.writelines(outError)
    ErrorFile.writelines("ErrorEnd\n")
    ErrorFile.close()
except:
    isConnectedFile.writelines("False\n")
isConnectedFile.close()
ssh.close()
