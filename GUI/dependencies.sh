#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 0 ]; then
    echo "Too many arguments"
    echo "Usage: $0 "
    exit 1
fi

packages_to_install="software-properties-common f3 smartmontools tmux sg3-utils sysstat gdisk parted time"

sudo apt-get install -y $packages_to_install

if ! dpkg -s $packages_to_install; then
    # Packages not installed
    return 1
fi

# TODO Check for OpenZFS
if ! dpkg -s zfsutils-linux &> /dev/null; then
    # OpenZFS not installed
    return 2
fi

return 0