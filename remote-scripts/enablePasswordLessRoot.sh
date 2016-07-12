#!/bin/bash
#AUTHOR : SHITAL SAVEKAR <v-shisav@microsoft.com>
#Description : Enables root user and sets password. Needs to run with sudo permissions.
#How to use : ./enablePasswordLessRoot.sh -password <new_root_password>

rm -rf /root/.ssh
cd /root
keyTarFile=sshFix.tar
if [ -e ${keyTarFile} ]; then
	echo | ssh-keygen -N ''
	rm -rf .ssh/*
	tar -xvf ${keyTarFile}
	echo "KEY_COPIED_SUCCESSFULLY"
else
	echo | ssh-keygen -N ''
	cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys
	echo "Host *" > /root/.ssh/config
	echo "StrictHostKeyChecking no" >> /root/.ssh/config
	rm -rf /root/.ssh/known_hosts
	cd /root/ && tar -cvf sshFix.tar .ssh/*
	echo "KEY_GENERATED_SUCCESSFULLY"
fi
