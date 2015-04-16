#!/usr/bin/python

from azuremodules import *

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking if root password is deleted or not...")
    
    passwd_output = Run("cat /etc/shadow | grep root")
    root_passwd = passwd_output.split(":")[1] 
    if (IsUbuntu()):
         if ('*' in root_passwd or '!' in root_passwd): 
             RunLog.info('root password is deleted in /etc/shadow in Ubuntu.') 
             ResultLog.info('PASS') 
         else:
             RunLog.info('root password is not deleted in /etc/shadow in Ubuntu.') 
             ResultLog.info('FAIL') 
    else:
         RunLog.info("Read Provisioning.DeleteRootPassword from /etc/waagent.conf..")
         outputlist=open("/etc/waagent.conf")
         for line in outputlist:
             if(line.find("Provisioning.DeleteRootPassword")!=-1):
                          break

         RunLog.info("Value ResourceDisk.DeleteRootPassword in /etc/waagent.conf.." + line.strip()[-1])
    
         if (('*' in root_passwd or '!' in root_passwd) and (line.strip()[-1] == "y")): 
                  RunLog.info('root password is deleted in /etc/shadow.') 
                  ResultLog.info('PASS') 
         elif(not('*' in root_passwd or '!' in root_passwd) and (line.strip()[-1] == "n")):
                  RunLog.info('root password is not deleted in /etc/shadow.') 
                  ResultLog.info('PASS') 
         if (('*' in root_passwd or '!' in root_passwd) and (line.strip()[-1] == "n")): 
                  RunLog.error('root password is deleted. Expected not deleted %s', passwd_output) 
                  ResultLog.error('FAIL') 
         elif(not('*' in root_passwd or '!' in root_passwd) and (line.strip()[-1] == "y")):
                  RunLog.error('root password not deleted. Expected deleted %s', passwd_output) 
                  ResultLog.error('FAIL')  
    UpdateState("TestCompleted") 

RunTest() 
