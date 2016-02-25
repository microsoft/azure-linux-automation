#!/usr/bin/python

from azuremodules import *

import argparse
import os
import re
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--distro', help='Please mention which distro you are testing', required=True, type = str)

args = parser.parse_args()
distro = args.distro

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Distro: " + distro)
    if(distro == "SLESHPC"):
        RunLog.info("Checking RDMA Driver version")
        output = Run("zypper info msft-lis-rdma-kmp-default")
        r = re.search("Version: (\S+)", output)
        if r is not None:
            RDMAVersion = r.groups()[0]
            RunLog.info("Verify RDMA Driver version: " + RDMAVersion)
            RDMA = True
        else:
            RunLog.error("Failed to verify RDMA Driver")
            RDMA = False

        RunLog.info("Checking NDdriver version")
        if os.path.isfile("/var/lib/hyperv/.kvp_pool_0"):
            with open("/var/lib/hyperv/.kvp_pool_0", "r") as f:
                lines = f.read()
            r = re.search("NdDriverVersion\0+(\d\d\d\.\d)", lines)
            if r is not None:
                NdDriverVersion = r.groups()[0]
                RunLog.info("Verify ND Driver version: " + NdDriverVersion)
                NDdrive = True
            else:
                RunLog.error("Failed to verify ND Driver")
                NDdrive = False                			
        else:
            RunLog.error("Failed to verify ND Driver")
            NDdrive = False

        RunLog.info("Checking KVP daemon process")
        output = Run("ps -ef | grep kvp | grep -v grep")
        if('hv_kvp_daemon' in output):
            RunLog.info("KVP daemon is running")
            KVPDaemon = True
        else:
            RunLog.error("KVP daemon is not running")
            KVPDaemon = False

        if RDMA and NDdrive and KVPDaemon:
            ResultLog.info('PASS')
        else:
            ResultLog.error('FAIL')
        UpdateState("TestCompleted")
        

    else:
        RunLog.info("The case is not supported against this distro,skip it")
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
		
RunTest()
