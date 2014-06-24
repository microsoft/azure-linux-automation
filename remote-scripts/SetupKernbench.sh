#!/bin/bash

echo "DOWNLOADING_KERNEL"
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.14.1.tar.xz
if [ $? = '0' ]; then
        echo "KERNEL_DOWNLOADED"
        echo "EXTRACTING_FILES"
        tar -xf linux-3.14.1.tar.xz
        echo "COPYING_TO_HOME_DIRECTORY"
        cp -ar ./linux-3.14.1/* ~
        echo "DOWNLOADING_KERNBENCH"
        wget http://ck.kolivas.org/apps/kernbench/kernbench-0.50/kernbench
        if [ $? = '0' ]; then
                echo "KERNBENCH_DOWNLOAD_DONE"
                chmod +x kernbench
                echo "READY_FOR_KERNBENCH_START"
        else
                echo "KERNBENCH_DOWNLOAD_FAILED"
        fi
else
        echo "KERNEL_DOWNLOAD_FAILED"
fi
