#!/usr/bin/python

from azuremodules import *

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking for ERROR and WARNING messages in  kernel boot line.")
    errors = Run("dmesg | grep -i error")
    warnings = Run("dmesg | grep -i warning")
    failures = Run("dmesg | grep -i fail")
    if (not errors and not warnings and not failures) :
        RunLog.error('ERROR/WARNING/FAILURE are not present in kernel boot line.')
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.info('ERROR/WARNING/FAILURE are  present in kernel boot line.')
        RunLog.info('Erros: ' + errors)
        RunLog.info('warnings: ' + warnings)
        RunLog.info('failures: ' + failures)
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest()
