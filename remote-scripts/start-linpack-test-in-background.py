#!/usr/bin/python
from azuremodules import *

command = "./runme_xeon64 >> runme_xeon64_console_output.txt 2>&1"
finalCommand = 'nohup ' + command + ' &'
Run("echo LINPACK-TEST-STARTED > runme_xeon64_console_output.txt")
Run(finalCommand)