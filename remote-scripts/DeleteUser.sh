#!/bin/bash
#V-SHISAV@MICROSOFT.COM

#HOW TO PARSE THE ARGUMENTS.. SOURCE - http://stackoverflow.com/questions/4882349/parsing-shell-script-arguments

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

duser=$duser


DeleteUser()
{
	if [ -e /etc/debian_version ]; then
		deluser $duser
		isUserDeleted=$?
	elif [ -e /etc/redhat-release ]; then
		userdel $duser
		isUserDeleted=$?
	elif [ -e /etc/SuSE-release ]; then
		userdel $duser
		isUserDeleted=$?
	fi
	if [ $isUserDeleted = "0" ]; then
	    echo "AUTOMATION_USER_DELETED"
	else
	    echo "AUTOMATION_USER_DELETE_FAILED"
	fi

}
DeleteUser
exit 0
