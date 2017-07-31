#!/bin/bash
#AUTHOR : SHITAL SAVEKAR <v-shisav@microsoft.com>
#Description : Enables passwordless authentication for root user.
#How to use : ./enablePasswordLessRoot.sh
#In multi VM cluster. Execute this script in one VM. It will create a sshFix.tar
#Copy this sshFix.tar to other VMs (/home/$user) in your cluster and execute same script. It will extract previously created keys.
#This way, all VMs will have same public and private keys in .ssh folder.
while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

rm -rf /home/$user/.ssh
cd /home/$user
keyTarFile=sshFix.tar
if [ -e ${keyTarFile} ]; then
	echo | ssh-keygen -N ''
	rm -rf .ssh/*
	tar -xvf ${keyTarFile}
	echo "KEY_COPIED_SUCCESSFULLY"
else
	echo | ssh-keygen -N ''
	cat /home/$user/.ssh/id_rsa.pub > /home/$user/.ssh/authorized_keys
	echo "Host *" > /home/$user/.ssh/config
	echo "StrictHostKeyChecking no" >> /home/$user/.ssh/config
	rm -rf /home/$user/.ssh/known_hosts
	cd /home/$user/ && tar -cvf sshFix.tar .ssh/*
	echo "KEY_GENERATED_SUCCESSFULLY"
fi
