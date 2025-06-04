#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 </path/to/drive>"
    exit 1
fi

_drive="$1"
_drive_name=$(basename "$_drive")

physical_sector_size=$(blockdev --getpbsz "$_drive")
current_sector_size=$(blockdev --getbsz "$_drive")

# Run badblocks
printf "\n\nRunning badblocks on %s\n" "$_drive"
touch "/tmp/${_drive_name}_badblocks"

if [ $current_sector_size -ne $physical_sector_size ]; then
    echo "Using emulated sector size of ${current_sector_size}e for $_drive"
else
    echo "Using native sector size of ${current_sector_size}n for $_drive"
fi

sudo badblocks -t random -b "$current_sector_size" -c 65535 -wsv -o "/tmp/${_drive_name}_badblocks" "$_drive"
