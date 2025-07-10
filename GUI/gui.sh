#!/bin/bash

# TODO Check for the presence of the whiptail library
packages_to_install="software-properties-common f3 smartmontools tmux sg3-utils sysstat gdisk parted time"
bash dependencies.sh "$packages_to_install"

case $? in
    1)
        printf "\n\nPlease check the log above carefully, and install the missing dependencies, as they weren't able to be installed automatically\n"
        exit 1
        ;;

    2)
        printf "\n\nPlease install the openZFS release for Debian\n"
        echo "See https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/index.html#installation"
        exit 2
        ;;

    *)
        echo "Dependencies checked successfully"
        ;;
esac

SELECTED_DRIVES=()

show_drives_in_dialog() {
    size="$(stty size)"
    whiptail --title "Available drives" --msgbox "$(lsblk -o NAME,MOUNTPOINTS,PHY-SEC,SIZE,TYPE)" "$(lsblk |wc -l)" 60
}

select_drives() {
    local -a _passed_array=($1)
    local -a all_drives
    local -a whiptail_drives=()

    readarray -t all_drives < <(lsblk -p -d -n -o NAME,SIZE)

    for line in "${all_drives[@]}"; do
        name=$(awk '{print $1}' <<< "$line")
        size=$(awk '{print $2}' <<< "$line")

        state="OFF"
        if [[ -n "$1" ]]; then
            for d in "${_passed_array[@]}"; do
                if [[ "$d" == "$name" ]]; then
                    state="ON"
                    break
                fi
            done
        fi

        whiptail_drives+=("$name" "$size" "$state")
    done

    selected=$(
        whiptail \
        --title "Select drives" \
        --backtitle "Selected drives: ${_passed_array[*]}" \
        --checklist "Select drives to process" 25 50 15 \
        "${whiptail_drives[@]}" \
        3>&2 2>&1 1>&3
    )

    exitstatus=$?
    if [ $exitstatus -ne 0 ]; then
        echo "Canceled selecting drives"
        return 1
    fi

    SELECTED_DRIVES=()
    for drive in $selected; do
        SELECTED_DRIVES+=("${drive//\"/}")
    done

    # echo "${SELECTED_DRIVES[@]}"
    return 0
}

burn_in_drives() {
    local -a _operations
    local -a _drives=("${SELECTED_DRIVES[*]}")
    # local -a _passed_array=($1)

    # echo "Size of ${_passed_array[*]} is ${#_passed_array[@]}"
    # if [[ ${#_passed_array[@]} -eq 0 ]]; then
    #     whiptail \
    #     --clear \
    #     --msgbox "Please select at least one drive to burn in" 10 50

    #     return 2
    # fi

    _operations=$(select_operations)

    # echo "_operations = $_operations & ${#_operations}"

    if [[ "${#_operations}" -eq "" ]]; then
        echo "Canceled burn in operations"
        return 1
        # exit
    fi

    echo "_operations = $_operations"
    echo "_drives = $_drives"

    # Delete previous records of passes
    rm -r /tmp/sd*_burnin.log
    rm -r /tmp/sd*_badblocks

    # tmux setup
    tmux new-session -d -s burnin_session
    tmux set -g pane-border-status top

    tmux send-keys "iotop -o -d 1|| exec bash" C-m
    tmux select-pane -T "iotop"

    for drive in $_drives; do
        drive_name=$(basename "$drive")
        cmd=(bash -c '$(pwd)/base.sh "$1" "$3" | tee "/tmp/$2_burnin.log" || exec bash' _ "$drive" "$drive_name" "${_operations[*]}")
        tmux split-window -v "${cmd[@]}"
        tmux select-pane -T "$drive"

        tmux select-layout tiled

    done
    tmux a -t burnin_session

    kill=$(
        whiptail \
        --yesno \
        --defaultno \
        "You have exited tmux. Would you like to kill the session and close all terminals running inside of it?\n\n \
If you wish to kill the tmux session from another terminal, use <tmux kill-session -t burnin-session>.\n
If you wish to re-open the tmux session from another terminal, use <tmux a -t burnin_session>." \
        20 60 \
        3>&2 2>&1 1>&3; echo $?
    )

    if [[ "$kill" -eq 0 ]]; then
        echo "Killing tmux session"
        tmux kill-session -t burnin_session
    fi
}

select_operations() {
    local -a _operations

    _operations=$(
    whiptail \
    --title "Burn in drives" \
    --checklist "Select the actions you want to run on the drives.\nThey will be run in the order displayed here." 25 60 15 \
        smart_test "Long S.M.A.R.T. test" on \
        wipe "Full disk wipe" on \
        format "Format drive to 512b sectors" off \
        badblocks "Badblocks" on \
        scrub "ZFS scrub + f3write + f3read" on \
    3>&2 2>&1 1>&3
    )
    
    exitstatus=$?
    if [ $exitstatus -ne 0 ]; then
        echo ""
        echo "Canceled selecting operations"
        return 1
    fi

    _operations=$(echo "$_operations" | tr -d \")
    echo "$_operations"
}

erase_drives() {
    local -a _drives=("${SELECTED_DRIVES[*]}")

    # echo "Size of ${_drives[*]} is ${#_drives[@]}"
    if [[ ${#_drives[@]} -eq 0 ]]; then
        whiptail \
        --clear \
        --msgbox "Please select at least one drive to erase" 10 50

        return 2
    fi

    erasure_conf1=$(
        whiptail \
        --clear \
        --title "Drive erasure confirmation" \
        --yesno "You have selected to erase the following drives:\n${_drives[*]}.\n\nAre you sure?" 25 75 \
        --defaultno \
        3>&2 2>&1 1>&3; echo $? \
    )

    # echo "erasure_conf1 = $erasure_conf1"

    if [ $erasure_conf1 -eq 0 ]; then
        erasure_conf2=$(whiptail \
        --title "Drive erasure confirmation" \
        --yesno "Are you REALLY sure? This will delete ALL data on the selected drives, including\n\n\
        • Partition table\n\
        • File system\n\
        • Setting the blocks as writeable by the OS" 25 75 \
        --fullbuttons \
        --yes-button "Yes, do as I say!" \
        --no-button "Return to menu" \
        --defaultno \
        3>&2 2>&1 1>&3; echo $? \
        )

        if [ $erasure_conf2 -ne 0 ]; then
            echo "Canceled erasing drives at step 2"
            return 2
        fi

        for drive in $_drives; do
            drive_name=$(basename "$drive")
            bash -c '$(pwd)/wipe_drive.sh "$0" | tee "/tmp/$1_burnin.log"' "$drive" "$drive_name"

        done
    fi

    
    if [ $erasure_conf1 -ne 0 ]; then
        echo "Canceled erasing drives"
        return 1
    fi
}

show_blurb() {
    more_info=$(
        whiptail \
        --clear \
        --yesno \
        "This script will burn in drives, a process that helps check for defective drives by submitting them \
to an intense cycle of writing and reading every block of data on the drive platter. Thus, this script is only suitable for MECHANICAL DRIVES. \
Any flash storage should be checked with a tool such as the Fight Flash Fraud (f3) suite of tools instead.\n\n\
    The script can, for each drive, run the following actions:\n\n\
        • A long S.M.A.R.T. test\n\
        • A basic check of the physical and logical sector sizes (no action will be taken)\n\
        • BadBlocks, if the drive supports it (see More information).\n\
        • Wipe the drive \n\
        • Destroy the partition table \n\
        • Create a deduplicated ZFS pool \n\
        • Run f3write and f3read on the pool \n\
        • Scrub the data on the pool \n\n\
    The resulting output will be written to /tmp/<drive>_burnin.log. Make sure to back those up if needed, as /tmp is emptied on reboot."\
        35 100 \
        --yes-button "OK" \
        --no-button "More information" \
        3>&2 2>&1 1>&3; echo $? \
    )

    if [ $more_info -eq 1 ]; then
        whiptail \
        --clear \
        --msgbox \
        "8+ TB mechanical drives are flaky with Badblocks. It is a great tool, but was designed for 32 bit systems, and the number of 512b sectors in an 8 TB drive is over the 32 bits signed integer limit.\n\n \
The reason it might work is that, if the drive is new enough, it will use Advanced Format, making its preferred sector size 4096b, artificially augmenting the number of adressable blocks by a factor of 8.\n\n \
Please note that, due to sector revectoring the drive level, the OS will most likely not be able to see all bad sectors, but only those who overflow the provided buffer of sectors at manufacturing time." \
        35 100 \
        3>&2 2>&1 1>&3; echo $?
    fi
}

exit_script() {
    # clear
    echo "Burn in script exited gracefully"
    exit
}



while true; do
    CHOICE=$(
    whiptail \
    --title "Menu" \
    --backtitle "Selected drives: ${SELECTED_DRIVES[*]}" \
    --menu "Choose an action" 25 78 16 \
        1 "Select drives to burn in" \
        2 "Burn in selected drives" \
        3 "Erase selected drives" \
        4 "Show available drives" \
        5 "What does this script do?" \
        6 "Exit" \
    --cancel-button "Exit" \
    3>&2 2>&1 1>&3
    )

    exit_status=$?

    if [ $exit_status == 1 ] ; then
        exit_script
    fi

    case $CHOICE in
        1)
            select_drives "${SELECTED_DRIVES[*]}"
            ;;

        2)
            burn_in_drives "${SELECTED_DRIVES[*]}"
            ;;

        3)
            erase_drives "${SELECTED_DRIVES[*]}"
            ;;

        4)
            show_drives_in_dialog
            ;;

        5)
            show_blurb
            ;;

        6)
            exit_script
            ;;
        
        *)
            exit_script
            ;;
    esac
done

