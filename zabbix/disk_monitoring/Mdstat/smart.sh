#!/bin/bash
/usr/sbin/smartctl -H $1 | grep overall-health | awk '{ print $6; }' > /etc/zabbix/dev/$FILE_DISK.smart.txt

cat /etc/zabbix/dev/$FILE_DISK.smart.txt