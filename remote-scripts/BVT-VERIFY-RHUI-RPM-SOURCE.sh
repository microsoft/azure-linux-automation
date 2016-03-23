#!/bin/bash
echo 'TestRunning' > state.txt
sudo bash rhui-rpm-source-check.sh > BVT-VERIFY-RHUI-RPM-SOURCE.sh.log
if [[ $? == 0 ]]; then
        echo 'PASS' > Summary.log
else
        echo 'FAIL' > Summary.log
fi
echo 'TestCompleted' > state.txt