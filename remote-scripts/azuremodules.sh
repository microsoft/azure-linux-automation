#!/bin/bash
#
# This script is library for shell scripts used in Azure Linux Automation.
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
#
#

function get_host_version ()
{
    dmesg | grep "Host Build" | sed "s/.*Host Build://"| awk '{print  $1}'| sed "s/;//"
}

function check_exit_status ()
{
    exit_status=$?
    message=$1

    if [ $exit_status -ne 0 ]; then
        echo "$message: Failed (exit code: $exit_status)" 
        if [ "$2" == "exit" ]
        then
            exit $exit_status
        fi 
    else
        echo "$message: Success" 
    fi
}

function detect_linux_ditribution_version()
{
    local  distro_version=`cat /etc/*release*|sed 's/"//g'|grep "VERSION_ID="| sed 's/VERSION_ID=//'| sed 's/\r//'`
    echo $distro_version
}

function detect_linux_ditribution()
{
    local  linux_ditribution=`cat /etc/*release*|sed 's/"//g'|grep "^ID="| sed 's/ID=//'`
    local temp_text=`cat /etc/*release*`
    if [ "$linux_ditribution" == "" ]
    then
        if echo "$temp_text" | grep -qi "ol"; then
            linux_ditribution='oracle'
        elif echo "$temp_text" | grep -qi "Ubuntu"; then
            linux_ditribution='ubuntu'
        elif echo "$temp_text" | grep -qi "SUSE Linux"; then
            linux_ditribution='suse'
        elif echo "$temp_text" | grep -qi "openSUSE"; then
            linux_ditribution='opensuse'
        elif echo "$temp_text" | grep -qi "centos"; then
            linux_ditribution='centos'
        elif echo "$temp_text" | grep -qi "Oracle"; then
            linux_ditribution='oracle'
        elif echo "$temp_text" | grep -qi "Red Hat"; then
            linux_ditribution='rhel'
        else
            linux_ditribution='unknown'
        fi
    fi
    echo $linux_ditribution
}

function updaterepos()
{
    ditribution=$(detect_linux_ditribution)
    case "$ditribution" in
        oracle|rhel|centos)
            yum -y update
            ;;
    
        ubuntu)
            apt-get update
            ;;
         
        suse|opensuse|sles)
            zypper --non-interactive --gpg-auto-import-keys update
            ;;
         
        *)
            echo "Unknown ditribution"
            return 1
    esac
}

function install_rpm ()
{
    package_name=$1
    rpm -ivh --nodeps  $package_name
    check_exit_status "install_rpm $package_name"
}

function install_deb ()
{
    package_name=$1
    dpkg -i  $package_name
    apt-get install -f
    check_exit_status "install_deb $package_name"
}

function apt_get_install ()
{
    package_name=$1
    apt-get install -y  --force-yes $package_name
    check_exit_status "apt_get_install $package_name"
}

function yum_install ()
{
    package_name=$1
    yum install -y $package_name
    check_exit_status "yum_install $package_name"
}

function zypper_install ()
{
    package_name=$1
    zypper --non-interactive in $package_name
    check_exit_status "zypper_install $package_name"
}

function install_package ()
{
    local package_name=$1
    ditribution=$(detect_linux_ditribution)
    case "$ditribution" in
        oracle|rhel|centos)
            yum_install $package_name
            ;;

        ubuntu)
            apt_get_install $package_name
            ;;

        suse|opensuse)
            zypper_install $package_name
            ;;

        *)
            echo "Unknown ditribution"
            return 1
    esac
}

function creat_partitions ()
{
    disk_list=($@)
    echo "Creating partitions on ${disk_list[@]}"

    count=0
    while [ "x${disk_list[count]}" != "x" ]
    do
       echo ${disk_list[$count]}
       (echo n; echo p; echo 2; echo; echo; echo t; echo fd; echo w;) | fdisk ${disk_list[$count]}
       count=$(( $count + 1 ))   
    done
}

function remove_partitions ()
{
    disk_list=($@)
    echo "Creating partitions on ${disk_list[@]}"

    count=0
    while [ "x${disk_list[count]}" != "x" ]
    do
       echo ${disk_list[$count]}
       (echo p; echo d; echo w;) | fdisk ${disk_list[$count]}
       count=$(( $count + 1 ))   
    done
}

function create_raid_and_mount()
{
# Creats RAID using unused data disks attached to the VM.
    local deviceName=$1
    local mountdir=$2
    local format=$3

    local uuid=""
    local list=""

    echo "IO test setup started.."
    list=(`fdisk -l | grep 'Disk.*/dev/sd[a-z]' |awk  '{print $2}' | sed s/://| sort| grep -v "/dev/sd[ab]$" `)

    lsblk

    echo "--- Raid $deviceName creation started ---"
    (echo y)| mdadm --create $deviceName --level 0 --raid-devices ${#list[@]} ${list[@]}
    check_exit_status "$deviceName Raid creation"

    time mkfs -t $format $deviceName
    check_exit_status "$deviceName Raid format" 

    mkdir $mountdir
    uuid=`blkid $deviceName| sed "s/.*UUID=\"//"| sed "s/\".*\"//"`
    echo "UUID of RAID device: $uuid"
    echo "UUID=$uuid $mountdir $format defaults 0 2" >> /etc/fstab
    mount $deviceName $mountdir
    check_exit_status "create_raid_and_mount"
}

function remote_copy ()
{
    remote_path="~"

    while echo $1 | grep -q ^-; do
       eval $( echo $1 | sed 's/^-//' )=$2
       shift
       shift
    done

    if [ "x$host" == "x" ] || [ "x$user" == "x" ] || [ "x$passwd" == "x" ] || [ "x$filename" == "x" ] ; then
       echo "Usage: -user <username> -passwd <user password> -host <host ipaddress> -filename <filename> -remote_path <location of the file on remote vm> -cmd <put/get>"
       exit -1
    fi

    if [ "$cmd" == "get" ] || [ "x$cmd" == "x" ]; then
       source_path="$user@$host:$remote_path/$filename"
       destination_path="."
    elif [ "$cmd" == "put" ]; then
       source_path=$filename
       destination_path=$user@$host:$remote_path/
    fi

    echo "sshpass -p $passwd scp -v -o StrictHostKeyChecking=no $source_path $destination_path 2>&1"
    status=`sshpass -p $passwd scp -v -o StrictHostKeyChecking=no $source_path $destination_path 2>&1`
    echo $status
}

function remote_exec ()
{
    while echo $1 | grep -q ^-; do
       eval $( echo $1 | sed 's/^-//' )=$2
       shift
       shift
    done
    cmd=$@
    if [ "x$host" == "x" ] || [ "x$user" == "x" ] || [ "x$passwd" == "x" ] || [ "x$cmd" == "x" ] ; then
       echo "Usage: -user <username> -passwd <user password> -host <host ipaddress> <onlycommand>"
       exit -1
    fi

    echo "sshpass -p $passwd ssh -v -o StrictHostKeyChecking=no $user@$host $cmd 2>&1"
    status=`sshpass -p $passwd ssh -v -o StrictHostKeyChecking=no $user@$host $cmd 2>&1`
    echo $status
}
