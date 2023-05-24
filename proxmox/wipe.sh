#!/bin/bash

DiskName=$(sfdisk -l | grep "/dev/sd*" | grep "Disk" | awk '{print $2}' | sed "s/://g" | sed "s/\/dev\/sdm//g" | sed '/^$/d')

for DiskName in $DiskName; do
    wipefs -a $DiskName
done