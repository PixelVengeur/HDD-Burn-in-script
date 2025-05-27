#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <operations[@]> </path/to/drive>"
    exit 1
fi

drive="$2"
operations="$1"
tmux select-pane -T "$drive"

echo "$drive"

for element in $operations; do
    #echo $element
    case $element in
        smart_test)
            echo "doing a smart test"
            ;;
        
        wipe)
            echo "doing a wipe"
            ;;

        badblocks)
            echo "doing a badblocks"
            ;;

        f3)
            echo "doing a f3"
            ;;

        scrub)
            echo "doing a scrub"
            ;;
        
        *)
            echo "doing a *"
            ;;
            
    esac
done