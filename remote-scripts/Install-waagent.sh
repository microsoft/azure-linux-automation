#!/bin/sh
# Installing waagent
echo "***WA Agent Installation***"
if [ -e /root/agent.py ]; then

        dos2unix -q /root/agent.py
        echo "Setting Execute bit on agent.py"
        chmod +x /root/agent.py
        mv /root/agent.py /usr/sbin/waagent
        /usr/sbin/waagent -setup
        sts=$?
        if [ 0 -eq ${sts} ]; then
                echo "waagent installed : SUCESS"

        else
                echo "waagent installation : FAILED "
                exit 1

        fi

else

        echo "waagent installation script not found..!!"
        echo "waagent installation : FAILED "

fi


#Verify Installation of waaagent

if [ -e /etc/init.d/waagent ]; then
	
	echo "Verify Install waagent : SUCESS"
else
	echo "Verify Install waagent : FAILED"
	exit

fi


