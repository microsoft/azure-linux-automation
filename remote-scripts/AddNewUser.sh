#!/bin/bash
#V-SHISAV@MICROSOFT.COM

#HOW TO PARSE THE ARGUMENTS.. SOURCE - http://stackoverflow.com/questions/4882349/parsing-shell-script-arguments

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

newUser=$newUser
newPassword=$newPassword

AddUser()
{
	if [ -e /etc/debian_version ]; then
		echo -e $newPassword'\n'$newPassword | adduser --gecos "" --force-badname -q $newUser
		isUserAdded=$?
	elif [ -e /etc/redhat-release ]; then
		#encryptedPass=$(perl -e 'print crypt($ARGV[0], "password")' $newPassword)
		#adduser $newUser -c "AutomationUser" -m -p $encryptedPass
		adduser $newUser -c "AutomationUser" -m
		isUserAdded=$?
		if [ $isUserAdded = "0" ]; then
			echo User added $newUser
			echo -e $newPassword'\n'$newPassword | passwd $newUser
			isUserAdded=$?
		fi
		
	elif [ -e /etc/SuSE-release ]; then
		useradd $newUser -c "AutomationUser" -m
		isUserAdded=$?
		if [ $isUserAdded = "0" ]; then
			echo User added $newUser
			echo -e $newPassword'\n'$newPassword | passwd $newUser
			isUserAdded=$?
		fi
	fi

	
	if [ $isUserAdded = "0" ]; then
	    echo "AUTOMATION_USER_ADDED"
	else
	    echo "AUTOMATION_USER_ADD_FAILED"
	fi

}
AddUser
exit 0
