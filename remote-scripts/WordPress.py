#!/usr/bin/python

import array
import os
import os.path
import time
import logging
import commands
import subprocess
import sys
import tarfile
import shutil
from azuremodules2 import *
import azuremodules2


WpUrl="http://wordpress.org/latest.tar.gz"
WpDst="/var/www/"

wpdbname="wpdb"
wpuser="wpuser"
DDLWpFile="Wordpress.DDL"
DtDbName="tradedb"
DtUser="trade"
DDLDtFile= "Daytrader.DDL"
PhpPackages = []
WebServerPackages = []
IbmWSPackages = []

class WrongRcException(Exception):
    def __init__(self,value):
        self.value=value

def SetPackagesList():
    LinuxDistro = IsUbuntu()
    if ( LinuxDistro ==  'Ubuntu' ):
        MySqlServerPackages.append("mysql-server")
        MySqlServerPackages.append("mysql-client")
        PhpPackages.append("php5")
        PhpPackages.append("php5")
        PhpPackages.append("php5-common")
        PhpPackages.append("libapache2-mod-php5")
        PhpPackages.append("php5-mysql")
        WebServerPackages.append("apache2")
        IbmWSPackages.append("bc")
        IbmWSPackages.append("xauth")
        IbmWSPackages.append("alien")

def SetGlobalParams():
    distroName = DetectLinuxDistro()
    RunLog.info ("Detected Linux Distro: " + distroName)
    SetRepos()
    global MysqlService
    global WsService
    global MySqlDaemon
    global ScriptDir
    global IbmWSBin
    global DayTraderPath
    global DayTraderPath
    global IbmJavaRpm
    global IbmMySqlConnector
    global IbmMaven
    global IbmDaytraderSchema
    global IbmDaytraderMySqlPlan
    LinuxDistro = IsUbuntu()
    if (LinuxDistro == 'Ubuntu'):
        MySqlDaemon = "mysqld"
        MysqlService = "mysql"
        WsService = "apache2"
    SetPackagesList()
    scriptPath = ScriptPath()
    ScriptDir=scriptPath
    IbmWSBin = ScriptDir + "/IBMWebSphere/wasce_setup-version-unix.bin"
    DayTraderPath = ScriptDir + "/IBMWebSphere/daytrader-2.2.1-source-release"
    IbmJavaRpm = ScriptDir + "/IBMWebSphere/ibm-java-x86_64-sdk-6.0-9.1.x86_64.rpm"
    IbmMySqlConnector = ScriptDir + "/IBMWebSphere/mysql-connector-java-5.1.18\mysql-connector-java-5.1.18.jar"
    IbmMaven = ScriptDir + "/IBMWebSphere/apache-maven-2.2.1"
    IbmDaytraderSchema = ScriptDir + "/IBMWebSphere/Table.ddl"
    IbmDaytraderMySqlPlan= ScriptDir + "/IBMWebSphere/daytrader-mysql-xa-plan.xml"


def InstallPhpPackages():
    InstallPackages(PhpPackages)

def InstallWebServerPackages():
    InstallPackages(WebServerPackages)

def InstallIbmWSPackages():
    InstallPackages(IbmWSPackages)

def InstallLampPackages():
    InstallMySqlPackages()
    InstallPhpPackages()
    InstallWebServerPackages()

def StartWebServer():
    isProcessRunning = VerifyProcess(WsService)
    if isProcessRunning!=True:
        StartService(WsService)

def StopWebServer():
    isProcessRunning = VerifyProcess(WsService)
    if isProcessRunning==True:
        StopService(WsService)

def SetUpWpDB():
    cmd="mysql -uroot -p'" + MysqlPwd + "'" + " < " +  DDLWpFile
    tmp = Run(cmd)
    if tmp=="Exception":
        RunLog.info("Mysql database setup creation Failed")
        result=False
        raise Exception
    else:
        RunLog.info("MySql database Setup started using %s DDL file",DDLWpFile)

    cmd ="mysql -uroot -p'" + MysqlPwd + "'" + ' -e "SHOW DATABASES"'
    tmp = Run(cmd)
    if tmp=="Exception":
        RunLog.info("SHOW DATABASES Failed")
        result=False
        raise Exception
    else:
        if wpdbname in tmp:
            RunLog.info("MySql database %s created successfully",wpdbname)
        else:
            RunLog.error("MySql database %s creation Fails",wpdbname)
            result=False
            raise Exception

    cmd ="mysql -uroot -p'" + MysqlPwd + "'" + ' -e "SELECT user from mysql.user"'
    tmp = Run(cmd)
    if tmp=="Exception":
        RunLog.info("Select User Failed")
        result=False
        raise Exception
    else:
        if wpuser in tmp:
            RunLog.info("MySql User %s created successfully",wpuser)
        else:
            RunLog.error("MySql user %s creation Fails",wpuser)
            result=False
	    raise Exception

def GetWordPress():
    wpfile=Download(WpUrl)
    UnTar(wpfile, WpDst)

def RestartWebServer():
    StopWebServer()
    StartWebServer()

def UpdateWordPressConfig():
    Hname=GetHostName()
    Wppwd=wpuser
    wpsampleconfig=WpDst+"wordpress/"+"wp-config-sample.php"
    wpconfig=WpDst+"wordpress/"+"wp-config.php"
    os.rename(wpsampleconfig, wpconfig)
    RunLog.info("Wordpress sample config file moved to config file")
    DbNameParam="database_name_here"
    DbUserParam="username_here"
    DbPwdParam="password_here"
    DbHostParam="localhost"
     
    ReplaceAllInFile(wpconfig, DbNameParam, wpdbname)
    ReplaceAllInFile(wpconfig, DbUserParam, wpuser)
    ReplaceAllInFile(wpconfig, DbPwdParam, Wppwd)
    ReplaceAllInFile(wpconfig, DbHostParam, Hname)


def WordPress():
    try:
        SetGlobalParams()
        InstallLampPackages()
        SetUpWpDB()
        GetWordPress()
        UpdateWordPressConfig()
        RestartWebServer()
        ReplaceAllInFile("/etc/mysql/my.cnf", "bind-address","#bind-address") 
        RestartMySqlServer()
    except Exception, ex:
        RunLog.exception(ex.message)
        exitcode=1
        RunLog.info ("Exitcode %s, WordPress Setup Failed"%exitcode)
        return exitcode
    else:
        exitcode=0
        RunLog.info ("Exitcode %s, Wordpress Setup Passed"%exitcode)
        return exitcode


WordPress()
#IBM()

#StopMySqlServer()
#StartMySqlServer()

#SetPackagesList()
#InstallLampPackages()

