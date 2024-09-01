#!/bin/bash

# Check if a drive is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /dev/sdX"
    exit 1
fi

drive="$1"
drive_name=$(basename "$drive")

printf '=%.0s' {1..40}; echo
echo "Processing drive $drive"
printf '=%.0s' {1..40}; echo

# exit 80

# Smartctl checks
if [[ "$drive" == /dev/nvme* ]]; then
    # For NVMe drives
    echo "$drive is an NVMe drive, running NVMe-specific tests"
    sudo smartctl -d nvme -i $drive
    sudo smartctl -d nvme -A $drive
    sudo smartctl -d nvme -t short "$drive"

    # Wait for the SMART test to complete
    echo "Waiting for SMART test to complete..."
    sleep 5
    while true; do
        status=$(sudo smartctl -l selftest /dev/nvme0 | grep "Self-test status:" | awk '{gsub(/^\(/, "", $7); print $7}')
        if [ "$status" = "" ]; then
            echo "SMART test completed for $drive."
            break
        else
            echo -ne "SMART test for $drive is $status done" \\r
            sleep 30  # Wait 30 seconds before checking again
        fi
    done
else
    # For SATA/SAS drives
    sudo smartctl -i "$drive"
    sudo smartctl -A "$drive"
    sudo smartctl -t short "$drive"

    # Wait for the SMART test to complete
    echo "Waiting for SMART test to complete..."
    while true; do
        status=$(sudo smartctl -l selftest "$drive" | grep "Self-test execution status:" | awk '{print $6}')
        if [ "$status" = "" ]; then
            echo "SMART test completed for $drive."
            break
        else
            echo -ne "SMART test for $drive is $status done" \\r
            sleep 2m  # Wait 1 minute before checking again
        fi
    done
fi

# TODO Menu avec un "ce script va faire sg_format (si besoin), badblocks & f3write"

physical_sector_size=$(sg_format /dev/sdh | awk '{ FS="=";} /Block size=/ {print $2}' | awk '{ FS=" ";} {print $1}')
logical_sector_size=$(sg_format /dev/sdh | awk '{ FS="=";} /Logical block size=/ {print $2}' | awk '{ FS=" ";} {print $1}')

# TODO sg_format les disques s'ils sont en 520 ou 528
# source: https://www.truenas.com/community/threads/troubleshooting-disk-format-warnings-in-truenas-scale.106051/
if [[ logical_sector_size -ne physical_sector_size ]]
then
    printf "\n\nPhysical and Logical sector sizes are different: %s/%s" "$physical_sector_size" "$logical_sector_size"
    echo "Running sg_format with sector size $physical_sector_size on $drive"
    time sg_format -v -F -s "$physical_sector_size" "$drive"
fi

# Run badblocks
printf "\n\nRunning badblocks on %s" "$drive"
if [[ physical_sector_size -eq 4096 ]];
then
    sudo badblocks -b 4096 -c 65535 -wsv "$drive" > "/tmp/${drive_name}_badblocks.log"
elif [[ physical_sector_size -eq 512 ]];
then
    sudo badblocks -b 512 -c 65535 -wsv "$drive" > "/tmp/${drive_name}_badblocks.log"
fi

# ZFS operations
printf "\n\nRunning ZFS operations on %s" "$drive"

printf "\tCreating pool %s" "TESTPOOL_${drive_name}"
sudo zpool create -f -o ashift=12 -O logbias=throughput -O compress=lz4 -O dedup=off -O atime=off -O xattr=sa "TESTPOOL_${drive_name}" "$drive"
printf "\tExporting pool %s" "TESTPOOL_${drive_name}"
sudo zpool export "TESTPOOL_${drive_name}"
printf "\tImporting pool %s" "TESTPOOL_${drive_name}"
sudo zpool import -d /dev/disk/by-id "TESTPOOL_${drive_name}"
printf "\tSetting permissions on pool %s" "TESTPOOL_${drive_name}"
sudo chmod -R ugo+rw "/TESTPOOL_${drive_name}"

# f3write and f3read tests
printf "\n\nRunning f3 operations on %s" "$drive"
printf "\tRunning f3write over %s" "${drive}"
sudo f3write "/TESTPOOL_${drive_name}"
printf "\tRunning f3read over %s" "${drive}"
sudo f3read "/TESTPOOL_${drive_name}"
printf "\tRunning zpool_scrub on %s" "TESTPOOL_${drive_name}"
sudo zpool scrub "TESTPOOL_${drive_name}"

printf "\n\nFinished processing %s" "$drive"
printf "%s has passed all tests and is now safe to use" "$drive"

exec bash