#!/bin/bash

DEVICE_MEGARAID=$(smartctl --scan  | grep /dev/bus | awk '{print $1}' | tail -1)
FILE_DISK=$(echo $1 | awk -F ',' '{print $2}')

/usr/sbin/smartctl -H -d $1 $DEVICE_MEGARAID | grep health | awk '{ print $6; }' > /etc/zabbix/dev/$FILE_DISK.smart.txt

cat /etc/zabbix/dev/$FILE_DISK.smart.txt