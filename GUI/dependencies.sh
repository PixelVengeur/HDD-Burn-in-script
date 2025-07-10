#!/bin/bash

# Check if the correct amount of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <space-separated string of packages to install>"
    exit 1
fi

packages_to_install=$1

# sudo apt-get install -y $packages_to_install

if ! dpkg -s $packages_to_install &> /dev/null; then
    # Packages not installed
    missing_packages=()
    for pekij in $packages_to_install; do
        if ! result=$(dpkg -s "$pekij"); then
            echo "$result"
            missing_packages+=("$pekij")
        fi
    done

    echo "Missing packages were detected: ${missing_packages[*]}"
    read -rp "Do you want to install the missing packages? (y/N) " install
    install=${install:-"N"}

    if [ $install = "y" ] || [ $install = "yes" ]; then
        echo "Installing missing packages"
        sudo apt-get install -y "${missing_packages[*]}"

        exit 0
    fi

    exit 1
fi

# TODO Check for OpenZFS
if ! dpkg -s zfsutils-linux &> /dev/null; then
    # OpenZFS not installed
    exit 2
fi

exit 0