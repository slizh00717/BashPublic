#!/bin/bash

osdid=$(systemctl | grep "osd@" | awk '{print $1}' | sed 's/.service//' | sed 's/ceph-osd@//' | sed 's/ceph-osd.target//' | sed '/^$/d')

for osdid in $osdid; do
    ceph osd down $osdid
    ceph osd out $osdid
    systemctl stop ceph-osd@$osdid.service
    pveceph osd destroy $osdid --cleanup 1
done
