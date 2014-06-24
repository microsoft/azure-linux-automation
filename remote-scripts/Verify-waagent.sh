#!/bin/sh
#Verify Installation of waaagent

if [ -e /etc/init.d/waagent ]; then
	
	echo "Verify Install waagent : Success"
else
	echo "Verify Install waagent : Failed"
	exit

fi
