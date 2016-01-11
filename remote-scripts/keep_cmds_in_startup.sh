#!/bin/bash
#
# This script places the server and client commands in the startup for the network performance test.
# Author: Srikanth M
# Email	: v-srm@microsoft.com
#
#####

testcommand=$*

if [[ -f /etc/rc.d/rc.local ]]
then
	if ! grep -q "${testcommand}" /etc/rc.d/rc.local
	then
		sed "/^\s*exit 0/i ${testcommand}" /etc/rc.d/rc.local -i
		if ! grep -q "${testcommand}" /etc/rc.d/rc.local
		then
			echo $testcommand >> /etc/rc.d/rc.local
		fi
	fi
fi

if [[ -f /etc/rc.local ]]
then
	if ! grep -q "${testcommand}" /etc/rc.local
	then
		sed "/^\s*exit 0/i ${testcommand}" /etc/rc.local -i
		if ! grep -q "${testcommand}" /etc/rc.local
		then
			echo $testcommand >> /etc/rc.local
		fi
	fi
fi

if [[ -f /etc/SuSE-release ]]
then
	if ! grep -q "${testcommand}" after.local
	then
		echo $testcommand >> /etc/rc.d/after.local
	fi
fi 
# ===
# if [[ -f /etc/rc.d/rc.local ]]
# then
# startup_file="/etc/rc.d/rc.local"
# elif  [[ -f /etc/rc.local ]]
# then
# startup_file="/etc/rc.local"
# elif  [[ -f /etc/SuSE-release ]]
# then
# startup_file="/etc/rc.d/after.local"
# fi

# if ! grep -q "${testcommand}" $startup_file
# then
	# sed "/^\s*exit 0/i ${testcommand}" $startup_file -i
	# if ! grep -q "${testcommand}" $startup_file
	# then
		# echo $testcommand >> $startup_file
	# fi
# fi

