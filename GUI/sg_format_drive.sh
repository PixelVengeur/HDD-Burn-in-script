#!/bin/bash

# Check if the correct amount of arguments is provided
if (( $# < 1 || $# > 2 )); then
    echo "Usage: $0 </path/to/drive> [<0|1>]"
    exit 1
fi

_drive="$1"
case "$2" in
    1) _format="true" ;;
    *) _format="false" ;;
esac

physical_sector_size=$(blockdev --getpbsz "$_drive")
logical_sector_size=$(blockdev --getss "$_drive")
preferred_sector_size=$(blockdev --getbsz "$_drive")

echo "The current sector size in use for $_drive is $preferred_sector_size"

# TODO sg_format les disques s'ils sont en 520 ou 528
# source: https://www.truenas.com/community/threads/troubleshooting-disk-format-warnings-in-truenas-scale.106051/
if [[ logical_sector_size -ne physical_sector_size ]]
then
    printf "\n\nPhysical and Logical sector sizes are different: %s/%s\n" "$physical_sector_size" "$logical_sector_size"
    
    if [ "$_format" = "true" ]; then
        echo "Running sg_format with sector size $physical_sector_size on $drive"
        # time sg_format -v -F -s "$physical_sector_size" "$drive"
    fi
else
    printf "\n\nPhysical and Logical sector sizes are identical: %s/%s\nAll good\n" "$physical_sector_size" "$logical_sector_size"
fi