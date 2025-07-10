#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 </path/to/drive>"
    exit 1
fi

_drive="$1"

# echo "doin a wipe on $_drive"

printf "Destroying leftover data and partition table on %s\n" "$_drive"
wipefs -a "$_drive"
sgdisk --zap-all "$_drive"
printf "Informing the kernel of partition table changes on %s\n" "$_drive"
partprobe