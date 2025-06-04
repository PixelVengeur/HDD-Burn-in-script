#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 </path/to/drive>"
    exit 1
fi

_drive="$1"
_drive_name=$(basename "$_drive")

echo "doin a zfs+f3 on $_drive"

# ZFS operations
printf "\n\nRunning ZFS operations on %s\n" "$_drive"

printf "\tCreating pool %s\n" "TESTPOOL_${_drive_name}"
sudo zpool create -f -o ashift=12 -O logbias=throughput -O compress=lz4 -O dedup=off -O atime=off -O xattr=sa -m "/mnt/TESTPOOL_${_drive_name}" "TESTPOOL_${_drive_name}" "$_drive"
printf "\tExporting pool %s\n" "TESTPOOL_${_drive_name}"
sudo zpool export "TESTPOOL_${_drive_name}"
printf "\tImporting pool %s\n" "TESTPOOL_${_drive_name}"
sudo zpool import -d /dev/disk/by-id "TESTPOOL_${_drive_name}"
printf "\tSetting permissions on pool %s\n" "TESTPOOL_${_drive_name}"
sudo chmod -R ugo+rw "/mnt/TESTPOOL_${_drive_name}"

# f3write and f3read tests
printf "\n\nRunning f3 operations on %s\n" "$_drive"

printf "\tRunning f3write over %s\n\n" "$_drive"
sudo time f3write "/mnt/TESTPOOL_${_drive_name}"

printf "\tRunning f3read over %s\n\n" "$_drive"
sudo time f3read "/mnt/TESTPOOL_${_drive_name}"

# Checking data integrity
printf "Checking data integrity via ZFS\n"

printf "\tRunning zpool_scrub on %s\n\n" "TESTPOOL_${_drive_name}"
sudo time zpool scrub "TESTPOOL_${_drive_name}"

printf "\t Destroying pool %s\n" "TESTPOOL_${_drive_name}"
sudo zpool destroy "TESTPOOL_${_drive_name}"