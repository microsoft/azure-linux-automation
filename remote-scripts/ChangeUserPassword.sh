#!/bin/bash
#V-SHISAV@MICROSOFT.COM

#HOW TO PARSE THE ARGUMENTS.. SOURCE - http://stackoverflow.com/questions/4882349/parsing-shell-script-arguments

while echo $1 | grep ^- > /dev/null; do
    eval $( echo $1 | sed 's/-//g' | tr -d '\012')=$2
    shift
    shift
done

oldPassword=$oldPassword
newPassword=$newPassword

UpdatePassword()
{
#echo $newPassword |  passwd $user --stdin
    if [ -e /etc/debian_version ]; then
        echo "Changing Password for : Ubuntu/Debian"
        echo -e $oldPassword'\n'$newPassword'\n'$newPassword | passwd
        exitVal=$?
        if [ $exitVal -ne "0" ]; then
                echo -e $newPassword'\n'$newPassword | passwd
                exitVal=$?
        fi
    fi
    if [ -e /etc/redhat-release ]; then
        echo "Changing Password for : Redhat/CentOS"
        echo -e $oldPassword'\n'$newPassword'\n'$newPassword | passwd
        exitVal=$?
    fi
    if [ -e /etc/SuSE-release ]; then
        echo "Changing Password for : SUSE/SLES"
        echo -e $oldPassword'\n'$newPassword'\n'$newPassword | passwd
        exitVal=$?
    fi
#    echo "exit Code : $exitVal"
    if [ $exitVal = "0" ]; then
        echo "PASSWORD_CHANGED_SUCCESSFULLY"
    else
        echo "PASSWWORD_CHANGE_FALED_EXIT_CODE_$exitVal"
    fi
}
UpdatePassword
exit 0
