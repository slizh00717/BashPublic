#!/bin/bash

LIST_DISK=/etc/zabbix/dev/disk_list.txt
/usr/sbin/smartctl --scan | grep dev | awk '{ print $1; }' >$LIST_DISK 2>&1
DISK_JSON=$(for i in $(cat $LIST_DISK); do printf "{\"{#DISK}\":\"$i\"},"; done | sed 's/^\(.*\).$/\1/')
printf "{\"data\":["
printf "$DISK_JSON"
printf "]}"
exit 0
