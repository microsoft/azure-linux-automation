#!/bin/bash
#
# This script is library for shell scripts used in Azure Linux Automation.
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
#
#

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

function apt_get_install ()
{
    package_name=$1
    apt-get install -y  --force-yes $package_name
    if [ $? -ne 0 ]; then
        echo "FAILED: apt_get_install $package_name"
        return 1
    fi
    echo "SUCCESS: apt_get_install $package_name"
}

function yum_install ()
{
    package_name=$1
    yum install -y $package_name
    if [ $? -ne 0 ]; then
        echo "FAILED: yum_install $package_name"
        return 1
    fi
    echo "SUCCESS: yum_install $package_name"
}

function zypper_install ()
{
    package_name=$1
    zypper --non-interactive in $package_name
    if [ $? -ne 0 ]; then
        echo "FAILED: zypper_install $package_name"
        return 1
    fi
    echo "SUCCESS: zypper_install $package_name"
}

function install_package()
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
