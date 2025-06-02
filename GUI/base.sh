#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 </path/to/drive> <operations[@]>"
    # exit 1
fi

drive="$1"
operations="$2"

echo "drive = $drive"
echo "operations = $operations"

for element in $operations; do
    #echo $element
    sleep "$(($RANDOM % 10))"
    case $element in
        smart_test)
            bash smart_test.sh "$drive"
            ;;
        
        wipe)
            bash wipe_drive.sh "$drive"
            ;;

        badblocks)
            bash badblocks.sh "$drive"
            ;;

        f3)
            bash f3.sh "$drive"
            ;;

        scrub)
            bash scrub.sh "$drive"
            ;;

        format)
            bash sg_format_drive.sh "$drive"
            ;;
        
        *)
            echo "doing a *"
            ;;
            
    esac
done

exec bash