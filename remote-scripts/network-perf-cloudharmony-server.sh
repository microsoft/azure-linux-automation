#!/bin/bash
#starting iperf server as a daemon
killall iperf3
iperf3 -s -D -p 8004
#
# Verify that the iperf server is running
pgrep iperf3
if [ $? -ne 0 ]; then
	echo "iperf server is not running as a daemon"
else
	echo "iperf server is running as a daemon"
fi
