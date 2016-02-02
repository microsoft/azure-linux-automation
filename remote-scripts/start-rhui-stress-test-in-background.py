#!/usr/bin/env python

from azuremodules import *
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument('-d', '--duration', help='specify how long run time(seconds) for the stress testing', required=True, type=int)
parser.add_argument('-p', '--package', help='spcecify package name to keep downloading from RHUI repo', required=True)
parser.add_argument('-t', '--timeout', help='specify the base value(seconds) to evaluate elapsed time of downloading package every time', required=True, type=int)
parser.add_argument('-s', '--save', help='save test data to log file', required=False, action='store_true')

args = parser.parse_args()

command = "python RHUI-STRESS-DOWNLOAD.py -d %s -p %s -t %s -s > out.out" % (args.duration, args.package, args.timeout)
finalCommand = 'nohup ' + command + ' &'
print(finalCommand)
Run(finalCommand)
