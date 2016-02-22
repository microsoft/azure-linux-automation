#!/usr/bin/env python
from azuremodules import *

def RunTest():
    UpdateState("TestRunning")
    cdsoutput = Run("cat /etc/yum.repos.d/rhui-load-balancers")
    RunLog.info("All CDS server name:" + cdsoutput)
    if(YumPackageInstall("nmap")==True):
      outputlist = re.split("\n", cdsoutput)
      RunLog.info("First CDS server name:" + outputlist[0])
      nmapoutput = Run("nmap "+outputlist[0])
      RunLog.info("Latency value between test machine and target CDS server" + nmapoutput) 
    else:
      RunLog.info("nmap install failed, skip nmap testing")
    
    
    downloadoutput = Run("yum install gcc --downloadonly")
    if("Download Only" in downloadoutput):
       RunLog.info("gcc download successfully")
    else:
       RunLog.info("gcc download failed")

    repolist = Run("yum repolist")

    if("extras" in repolist and "error" not in repolist and "Download Only" in downloadoutput):
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else:
        ResultLog.info('FAIL')
        UpdateState("TestCompleted")
RunTest()