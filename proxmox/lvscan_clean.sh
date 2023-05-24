#!/bin/bash

lvm_disk=$(lvscan | grep "ACTIVE" | grep "/dev/ceph" | awk '{print $2}' | sed "s/'//g")

for lvm_disk in $lvm_disk; do
    lvchange -a n $lvm_disk
    lvremove $lvm_disk
done
