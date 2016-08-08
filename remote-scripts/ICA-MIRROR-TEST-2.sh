#!/bin/bash
curl -sSL https://get.docker.com | sh > ICA-MIRROR-TEST-2.sh.log
if [[ $? == 0 ]]; then
        echo 'PASS' > Summary.log
else
        echo 'FAIL' > Summary.log
fi
echo 'TestCompleted' > state.txt