#!/bin/bash
#This script will reports network statistics and CPU usage
duration=$1
filename=$2
#Displays network devices vital statistics for eth0 and lo
sar -n DEV 1 $duration 2>&1 >> $filename/sar.log &
for i in $(seq 1 $duration)
do
#Displays the CPU usage
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}' >> $filename/cpu_usage.log
sleep 1
done
