#!/usr/bin/python

import argparse
import sys
from azuremodules import *
import paramiko

SetVnetGlobalParameters()
RemoveICAVMsFromDBfile()
RemoveICAVMsFromREVfile()

