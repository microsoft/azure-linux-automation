#!/bin/bash
#
# This script places the server and client commands in the startup for the network performance test.
# Author: Sivakanth R
# Email	: v-sirebb@microsoft.com
#
#####

vm_type=$1
username=$2
server_ip=$3

code_path="/home/$username/code"
error_file="$code_path/error_file.log"
testcommand=""

if [ "$vm_type" = "server" ]
then
	testcommand="bash $code_path/server_start.sh $username >> $code_path/server.log&" 
elif [ "$vm_type" = "client" ]
then
	if [ "$#" -ne 3 ]; then
		echo "Illegal number of parameters passed exiting..." >> $error_file
	fi
	testcommand="bash $code_path/client_start.sh $server_ip $username >> $code_path/client.log&"
else
	echo "Invalid arguments passed" >> $error_file
fi

bash $code_path/keep_cmds_in_startup.sh $testcommand
