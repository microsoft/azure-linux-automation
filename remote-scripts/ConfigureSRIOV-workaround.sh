#!/bin/bash

DISTRO=`grep -ihs "buntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`
if [[ $DISTRO =~ "Ubuntu" ]];
then
	#A temporary workaround for SRIOV issue.
	macAddr=`cat /sys/class/net/eth0/address`
	echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"hv_netvsc\", ATTR{address}==\"${macAddr}\", NAME=\"eth0\"" > /etc/udev/rules.d/70-persistent-net.rules
	echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"mlx4_core\", ATTR{address}==\"${macAddr}\", NAME=\"vf0\"" >> /etc/udev/rules.d/70-persistent-net.rules
	#sed -i '/rename*/c\vf0' /etc/network/interfaces
	echo "SYSTEM_RESTART_REQUIRED"
fi
exit 0