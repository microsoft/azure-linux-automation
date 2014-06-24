#!/bin/bash

echo "STARTING_KERNBENCH"
nohup ./StartKernbench.sh &
if [ $? = '0' ]; then
        echo "KERNBENCH_STARTED"
else
        echo "KERNBENCH_FAILED_TO_START"
fi
