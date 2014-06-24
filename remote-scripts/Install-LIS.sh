#!/bin/sh
# Install-LIS.sh
# Description:
#	 1. Install LIS from the tarball.
#	 2. Verify if LIS is installed.
#    3. Verify the modules are present in /lib/modules.
#        
DEBUG_LEVEL=3


dbgprint()
{
    if [ $1 -le $DEBUG_LEVEL ]; then
        echo "$2"
    fi
}

if [ -e $HOME/constants.sh ]; then
 . $HOME/constants.sh
else
 echo "ERROR: Unable to source the config file."
 exit 1
fi


if [ ! ${LIS_TARBALL} ]; then
  dbgprint 0 "The TARBALL variable is not defined."
  dbgprint 0 "Aborting the LIS Installation."
    UpdateTestState "TestAborted"
    exit 20
fi




dbgprint 3 "Extracting LIS sources from ${LIS_TARBALL}"

tar -xmf ${LIS_TARBALL}
sts=$?
if [ 0 -ne ${sts} ]; then
    dbgprint 0 "tar failed to extract the LIS from the tarball: ${sts}" 
    exit 40
fi

ROOTDIR="hv"
#ROOTDIR=(`tar tf hv-rhel6.3-july9-2012.tar | sed -e 's@/.*@@' | uniq`)
if [ ! -e ${ROOTDIR} ]; then
    dbgprint 0 "The tar file did not create the directory: ${ROOTDIR}"
    exit 50
fi

cd ${ROOTDIR} 

install_ic_rhel6()
{
	dbgprint 0  "**************************************************************** "
        dbgprint 0  "This is RHEL6 and above LIS installation "
        dbgprint 0  "*****************************************************************"

	./rhel6-hv-driver-install >>./Install-LIS.log
	sts=$?
	if [ 0 -ne ${sts} ]; then
		dbgprint 0 "Execution of install script failed: ${sts}" 
	    exit 0
	else
		dbgprint 0 "LIS installation on RHEL 6.x : Success"
	fi

	cd tools
	
	gcc -o kvp_daemon hv_kvp_daemon.c
	sts=$?
	if [ 0 -ne ${sts} ]; then
		dbgprint 0 "Execution of install script failed: #${sts}" 
		dbgprint 0 "KVP daemon compiled : Failed"
	    exit 0
	else
		dbgprint 0 "KVP daemon compiled : success"
	fi
	
	#update rc.local
	
	echo "./root/${ROOTDIR}/tools/kvp_daemon" >> /etc/rc.local
}

echo "**LIS Driver Installation**"
if [ -e /etc/redhat-release ]  ; then
	install_ic_rhel6	
	
else
    echo "Not a supported distro for LIS Installation"
	exit
	
fi
