#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko
import azuremodules


SetVnetGlobalParameters()
ConfigureResolvConf()
ConfigureHostsFile()
