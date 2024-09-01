#!/bin/bash

# Check if at least one drive is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 /dev/sdX [/dev/sdY ...]"
    exit 1
fi

# Create a new tmux session
tmux new-session -d -s burnin_session

# Loop through each provided drive
first_pane=true
for drive in "$@"
do
    # If this is the first pane, just select it; otherwise, split the window
    if $first_pane
    then
        first_pane=false
        tmux send-keys "bash burn_in_drive.sh $drive" C-m
    else
        tmux split-window -v "bash burn_in_drive.sh $drive"
        tmux select-layout tiled
    fi
done

# Attach to the tmux session to show it in the current terminal
tmux attach-session -t burnin_session