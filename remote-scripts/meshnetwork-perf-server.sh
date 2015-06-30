#!/bin/bash
#Running iperf3 server for 8001 to 8100 ports
killall iperf3 > /dev/null 2>&1
for i in {8001..8100}
do
	iperf3 -s -D -p $i
done
count=$(pgrep iperf3 | wc -l)
if [ $count -eq 100 ]; then
	echo "iperf server is running and available from 8001 to 8100 ports in `hostname`"
else
	echo "iperf server is not running as a daemon"
fi

exit 0
