#!/usr/bin/python

from azuremodules import *



import argparse
import sys
import time
        #for error checking
validPlatformValues = ["532","540","541", "542", "550"]
parser = argparse.ArgumentParser()

parser.add_argument('-c', '--serverip', help='specifies server VIP of server name', required=True)
parser.add_argument('-u', '--udp', help='switch : starts the client in udp data packets sending mode.', choices=['yes', 'no'] )
parser.add_argument('-p', '--port', help='specifies which port should be used', required=True, type= int)
parser.add_argument('-m', '--print_mss', help='print TCP maximum segment size (MTU - TCP/IP header) ', choices=['yes', 'no'])
parser.add_argument('-M', '--mss', help='set TCP maximum segment size (MTU - 40 bytes)', type = int)
parser.add_argument('-i', '--interval', help='specifies frequency of the output to be displyed on screen', type= int)
parser.add_argument('-l', '--length', help='length of buffer to read or write (default 8 KB)', type= int)
parser.add_argument('-P', '--parallel', help='number of parallel client threads to run', type= int)
parser.add_argument('-t', '--time', help='duration for which test should be run', required=True)
#parser.add_argument('-p', '--port', help='specifies which port should be used', required=True, type= int)
args = parser.parse_args()
                #if no value specified then stop
command = 'iperf -c ' + args.serverip +  ' -p' + str(args.port) + ' -t' + args.time + ' -f K'
if args.interval != None :
        command = command + ' -i' + str(args.interval)
if args.udp == 'yes':
        command = command + ' -u'
if args.mss != None:
        command = command + ' -M' + str(args.mss)
if args.print_mss == 'yes':
        command = command + ' -m'
if args.parallel != None :
        command = command + ' -P' + str(args.parallel)
if args.length != None:
        command = command + ' -l' + str(args.length)
finalCommand = 'nohup ' + command + ' >>  iperf-client.txt &'




def RunTest(client):
	UpdateState("TestRunning")
	RunLog.info("Starting iperf Client..")
	RunLog.info("Executing Command : %s", client)
	temp = Run(client)
	cmd ='sleep 2'
	tmp = Run(cmd)
	sleepTime = int(args.time) + 10 
	cmd = 'sleep ' + str(sleepTime)
	tmp = Run(cmd)

	status = isProcessRunning('iperf -c')
	if status == "True":
		time.sleep(60)
		Run('echo "ProcessRunning" >> iperf-client.txt')
		Run('echo "Waiting for 60 secs to let iperf process finish" >> iperf-client.txt')
		status = isProcessRunning('iperf -c')
		if status == "True":
			Run('echo "ProcessRunning even after 60 secs delay" >> iperf-client.txt')
		else:
			Run('echo iperf process finished after extra wait of 60 secs >>iperf-client.txt')
	#else:
		#Run('echo "ProcessRunning" >> iperf-client.txt')

client = finalCommand
#Run('echo "TestStarted" > iperf-client.txt')
RunTest(client)
Run('echo "TestComplete" >> iperf-client.txt')
AnalyseClientUpdateResult()
