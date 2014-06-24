#!/bin/sh
#########################################################
# ICA_VMSetup.sh
#
#Description : This script installs packages required for ICA and
# 			   Configures test VHD for ICA test run
# Author : Amit Pawar [ v-ampaw@microsoft.com ]

##############################################################################

#DEBUG_LEVEL=3

echo "***Logs of ICA_VMSetup.sh***"  
withErrors=0
dbgprint()
{
    #if [ $1 -le $DEBUG_LEVEL ]; then
        #echo "$1"
        
		echo  "$1"  
		
    #fi
}




dbgprint "Preparing the VHD for ICA..."



#installing gcc. dos2unix, make and python
  if [ -e /etc/debian_version ]; then

        dbgprint "Installing gcc.."
		
		echo yes|apt-get install gcc 
		if [ "$?" = "0" ]; then 
			dbgprint "Install gcc  : SUCCESS"
		else 
			dbgprint "Install gcc  : FAILED"
			withErrors=1
		fi


        dbgprint "Installing make.."
		
		echo yes|apt-get install make
		if [ "$?" = "0" ]; then
			dbgprint "Install make  : SUCCESS"
		else
			dbgprint "Install  make : FAILED"
			withErrors=1
		fi

        dbgprint "Installing python.."
		
		echo yes|apt-get install python 
		if [ "$?" = "0" ]; then
			dbgprint "Install python  : SUCCESS"
		else 
			dbgprint "Install python  : FAILED"
			withErrors=1
		fi

        dbgprint "Installing python-pyasn1.." 
		
		echo yes|apt-get install python-pyasn1 
		if [ "$?" = "0" ]; then
			dbgprint "Install python-pyasn1  : SUCCESS"
		else 
			dbgprint "Install python-pyasn1  : FAILED"
			withErrors=1
		fi
		
		dbgprint "Installing iperf.."
		
		echo yes|apt-get install iperf 
		if [ "$?" = "0" ]; then
			dbgprint "Install iperf  : SUCCESS"
		else 
			dbgprint "Install iperf  : FAILED"
			withErrors=1
		fi
		
		dbgprint "Installing bind9 dnsutils.."
		
		echo yes|apt-get install bind9 dnsutils 
		if [ "$?" = "0" ]; then
			dbgprint "Install bind9 dnsutils  : SUCCESS"
		else 
			dbgprint "Install bind9 dnsutils  : FAILED"
			withErrors=1
		fi

         dbgprint "Removing NetworkManager.."
		 
		 echo yes | aptitude purge network-manager 
		 
		 if [ "$?" = "0" ]; then
			dbgprint "Remove Network Manager  : SUCCESS"
		else 
			dbgprint "Remove Network Manager  : FAILED"
			withErrors=1
		fi
		
		dbgprint "Updating the packages.."
		
		echo yes|apt-get update 
		if [ "$?" = "0" ]; then
			dbgprint "Update Packages  : SUCCESS"
		else 
			dbgprint "Update Packages  : FAILED"
			withErrors=1
		fi

        dbgprint "Upgrading the kernel.."
		
		echo yes|apt-get upgrade 
		if [ "$?" = "0" ]; then
			dbgprint "Upgrade Kernel  : SUCCESS"
		else 
			dbgprint "Upgrade Kernel  : FAILED"
			withErrors=1
		fi

  fi

  if [ -e /etc/redhat-release ]; then

        dbgprint "Installing gcc.." 
		
		echo yes|yum install gcc 
		if [ "$?" = "0" ]; then
			dbgprint "Install gcc  : SUCCESS"
		else 
			dbgprint "Install gcc  : FAILED"
			withErrors=1
		fi


        dbgprint "Installing make.."
		
		echo yes|yum install make 
		if [ "$?" = "0" ]; then
			dbgprint "Install make  : SUCCESS"
		else 
			dbgprint "Install  make  : FAILED"
			withErrors=1
		fi

        dbgprint "Installing python.."
		
		echo yes|yum install python 
		if [ "$?" = "0" ]; then
			dbgprint "Install python  : SUCCESS"
		else 
			dbgprint "Install python  : FAILED"
			withErrors=1
		fi

        dbgprint "Installing python-pyasn1.."
		
		echo yes|yum install python-pyasn1  
		if [ "$?" = "0" ]; then
			dbgprint "Install python-pyasn1  : SUCCESS"
		else 
			dbgprint "Install python-pyasn1  : FAILED"
			withErrors=1
		fi
		
		dbgprint "Installing iperf.."
		
		echo yes|yum install iperf  
		if [ "$?" = "0" ]; then
			dbgprint "Install iperf  : SUCCESS"
		else 
			dbgprint "Install iperf  : FAILED"
			withErrors=1
		fi

        dbgprint "Removing NetworkManager.."
		
		echo yes|yum remove NetworkManager 
		if [ "$?" = "0" ]; then
			dbgprint "Remove Network Manager  : SUCCESS"
		else 
			dbgprint "Remove Network Manager  : FAILED"
			withErrors=1
		fi

        dbgprint "Updating the packages.."
		
		echo yes|yum update 
		if [ "$?" = "0" ]; then
			dbgprint "Update Packages  : SUCCESS"
		else 
			dbgprint "Update Packages  : FAILED"
			withErrors=1
		fi
		
		dbgprint "Upgrading the kernel.."
		
		echo yes|yum upgrade 
		if [ "$?" = "0" ]; then
			dbgprint "Upgrade kernel  : SUCCESS"
		else 
			dbgprint "Upgrade kernel  : FAILED"
			withErrors=1
		fi


  fi

  if [ -e /etc/SuSE-release ]; then

        dbgprint "Installing gcc.."
		
		zypper --non-interactive install gcc 
		if [ "$?" = "0" ]; then
			dbgprint "Install gcc  : SUCCESS"
		else 
			dbgprint "Install gcc  : FAILED"
			withErrors=1
		fi


        dbgprint "Installing make.."
		
		zypper --non-interactive install make 
		if [ "$?" = "0" ]; then
			dbgprint "Install make  : SUCCESS"
		else 
			dbgprint "Install  make  : FAILED"
			withErrors=1
		fi

        dbgprint "Installing python.."
		
		zypper --non-interactive install python 
		if [ "$?" = "0" ]; then
			dbgprint "Install python  : SUCCESS"
		else 
			dbgprint "Install python  : FAILED"
			withErrors=1
		fi

        dbgprint "Installing python-pyasn1.."
		
		zypper --non-interactive install python-pyasn1  
		if [ "$?" = "0" ]; then
			dbgprint "Install python-pyasn1  : SUCCESS"
		else 
			dbgprint "Install python-pyasn1  : FAILED"
			withErrors=1
		fi
		
		dbgprint "Installing iperf.."
		
		zypper --non-interactive install iperf  
		if [ "$?" = "0" ]; then
			dbgprint "Install iperf  : SUCCESS"
		else 
			dbgprint "Install iperf  : FAILED"
			withErrors=1
			
		fi
		
		dbgprint "Installing bind-utils.."
		
		zypper --non-interactive install bind-utils  
		if [ "$?" = "0" ]; then
			dbgprint "Install bind-utils  : SUCCESS"
		else 
			dbgprint "Install bind-utils  : FAILED"
			withErrors=1
		fi
		

        dbgprint "Removing NetworkManager.."
		
		zypper --non-interactive remove NetworkManager 
		if [ "$?" = "0" ]; then
			dbgprint "Remove Network Manager  : SUCCESS"
		else 
			dbgprint "Remove Network Manager  : FAILED"
			withErrors=1
		fi

        dbgprint "Updating the packages.."
		
		zypper --non-interactive update 
		if [ "$?" = "0" ]; then
			dbgprint "Update Packages  : SUCCESS"
		else 
			dbgprint "Update Packages  : FAILED"
			withErrors=1
		fi

		dbgprint "Upgrading the kernel.."
		
		zypper --non-interactive up 
		if [ "$?" = "0" ]; then
			dbgprint "Upgrade kernel  : SUCCESS"
		else 
			dbgprint "Upgrade kernel  : FAILED"
			withErrors=1
		fi


  fi


#installing icadaemon, git and lcov
     
	tar -xmf icatest-0.1.tar.gz
	chmod 777 ./icatest-0.1/setup.py
	dbgprint "Installing Icadaemon.."
   	cd ./icatest-0.1
	python setup.py install  
	if [ "$?" = "0" ]; then 
		dbgprint "Icadaemon installed : SUCCESS"
	else 
		dbgprint "Icadaemon installed : FAILED"
		withErrors=1
	fi
	cd ~
  
  

	if [ -e /etc/debian_version ]; then
	
		dbgprint "Installing git.."
		echo yes|apt-get install git 
		if [ "$?" = "0" ]; then 
			dbgprint "git installed : SUCCESS"
		else 
			dbgprint "git installed : FAILED"
			withErrors=1
		fi
	else
	
	    dbgprint "Installing git.."
		tar -xmf git-1.7.10.tar.gz
		cd git-1.7.10 
		./configure   
		make   
		if [ "$?" -ne "0" ]; then
			dbgprint "git installed : FAILED"
			withErrors=1
		else
			make install  
			if [ "$?" = "0" ]; then
				dbgprint "git installed : SUCCESS"
			else 
				dbgprint "git installed : FAILED"
				withErrors=1
			fi
    			
		fi
		cd ~
	fi

    
  

  
    dbgprint "Installing Lcov.."
    tar -xmzf lcov-1.9.tar.gz
	cd lcov-1.9
	make install  
	if [ "$?" = "0" ]; then
		dbgprint "Lcov installed : SUCCESS"
	else 
		dbgprint "Lcov installed : FAILED"
		withErrors=1
	fi;
    cd ~
  


  #Enabling essential services
  if [ -e /etc/redhat-release ]; then
   chkconfig rpcbind on  && chkconfig sshd on  && chkconfig nfs on 
   fi

  if [ -e /etc/SuSE-release ]; then 
   /sbin/SuSEfirewall2 off 
   fi
   
	if [ $withErrors -ne 0 ]; then
		dbgprint "Failed to install some packages!!!"
		dbgprint "Exiting with Errors"
		exit 10
	fi
