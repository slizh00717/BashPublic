#!/bin/bash

servername=$1
vmid=$2
memory_count=$3
network_vmbr=$4
load_image=$5
disk_storage=$6
Root_Password=$7
disk_count=$8

if [[ -z "${servername}" ]]; then
    echo "Server name not provided"
    exit 1
elif [[ "${servername}" == "--help" ]]; then
    echo "./create_server.sh <ServerName> <VMID> <Memory_Count> <Network Vmbr> <Name CloudImage> <Name Storage> <Root Password> <Disk size>"
    exit 0
fi

if [[ -z "${vmid}" ]]; then
    echo "Server number not provided"
    exit 1
fi

if [[ -z "${memory_count}" ]]; then
    echo "Amount of RAM not provided"
    exit 1
fi

if [[ -z "${network_vmbr}" ]]; then
    echo "vmbr name not provided"
    exit 1
fi

if [[ -z "${load_image}" ]]; then
    echo "Server image not provided"
    exit 1
fi

if [[ -z "${disk_storage}" ]]; then
    echo "Disk name not provided"
    exit 1
fi

if [[ -z "${Root_Password}" ]]; then
    echo "Root password not provided"
    exit 1
fi

if [[ -z "${disk_count}" ]]; then
    echo "Shared disk not provided"
    exit 1
fi

# Create a new virtual machine
qm create "${vmid}" --name "${servername}" --memory "${memory_count}" --net0 virtio,bridge=vmbr"${network_vmbr}"

# Import the disk image
qm importdisk "${vmid}" "${load_image}" "${disk_storage}"

# Set the necessary parameters
qm set "${vmid}" --ostype=l26
qm set "${vmid}" --scsihw virtio-scsi-pci --scsi0 "${disk_storage}:vm-${vmid}-disk-0"
qm set "${vmid}" --ide2 "${disk_storage}:cloudinit"
qm set "${vmid}" --boot c --bootdisk scsi0

# Resize the disk
qm resize "${vmid}" scsi0 "+8G"

# Set the cloud-init user and password
qm set "${vmid}" --ciuser root
qm set "${vmid}" --cipassword "${Root_Password}"