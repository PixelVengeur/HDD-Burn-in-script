#!/bin/bash

# Install dependencies
printf "Installing dependencies...\n\n"
#sleep 3
sudo apt-get install -y software-properties-common f3 smartmontools tmux sg3-utils htop sysstat gdisk parted

# ZFS Install
# https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/index.html#installation

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
    drive_name=$(basename "$drive")
    # If this is the first pane, just select it; otherwise, split the window
    if $first_pane
    then
        first_pane=false
        tmux send-keys "bash burn_in_drive.sh $drive |tee '/tmp/${drive_name}_badblocks.log'" C-m
    else
        tmux split-window -v "bash burn_in_drive.sh $drive |tee '/tmp/${drive_name}_badblocks.log'"
        tmux select-layout tiled
    fi
done

# Add htop and iostat to the display
tmux split-window -v "htop"
tmux split-window -v "iostat -dhs 1"
tmux select-layout tiled

# Attach to the tmux session to show it in the current terminal
tmux attach-session -t burnin_session