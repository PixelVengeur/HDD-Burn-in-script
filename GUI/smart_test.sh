#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 </path/to/drive>"
    exit 1
fi

_drive="$1"

echo "doin a smart on $_drive"

# Smartctl checks
if [[ "$_drive" == /dev/nvme* ]]; then
    # For NVMe drives
    echo "$_drive is an NVMe drive, running NVMe-specific tests"
    sudo smartctl -d nvme -i "$_drive"
    sudo smartctl -d nvme -A "$_drive"
    sudo smartctl -d nvme -t long "$_drive"

    # Wait for the SMART test to complete
    echo "Waiting for SMART test to complete..."
    sleep 5
    while true; do
        status=$(sudo smartctl -l selftest "$_drive" |grep "Self-test status:" |awk '{gsub(/^\(/, "", $7); print $7}')
        if [ "$status" = "" ]; then
            echo "SMART test completed for $_drive."
            break
        else
            echo -ne "SMART test for $_drive is $status" \\r
            sleep 30  # Wait 30 seconds before checking again
        fi
    done
else
    # For SATA/SAS drives
    sudo smartctl -i "$_drive"
    sudo smartctl -A "$_drive"
    sudo smartctl -t long "$_drive"

    # Wait for the SMART test to complete
    echo "Waiting for SMART test to complete..."
    while true; do
	    status=$(sudo smartctl -l selftest "$_drive" |grep "Self-test execution status:" |awk -F "status:" '{print $2}' | awk '{$1=$1};1')
        if [ "$status" = "" ]; then
            echo "DONE"
            echo "SMART test completed for $_drive."
            break
        else
            echo -ne "SMART test for $_drive: $status" \\r
            sleep 30  # Wait 30 seconds before checking again
        fi
    done
fi