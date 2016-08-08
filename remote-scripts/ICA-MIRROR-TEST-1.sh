#!/bin/bash
curl -sSL http://mirror.azure.cn/repo/install-docker-engine.sh | sh > ICA-MIRROR-TEST-1.sh.log
if [[ $? == 0 ]]; then
        echo 'PASS' > Summary.log
else
        echo 'FAIL' > Summary.log
fi
echo 'TestCompleted' > state.txt