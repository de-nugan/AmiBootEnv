#!/bin/bash
clear

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"
. "${my_path}/mount-device-function.sh"

# NB This seems to be the only way to get Amiberry to observe a custom config dir
AMIBERRY_HOME_DIR="${uae_base_path}"
AMIBERRY_CONFIG_DIR="${uae_config_path}"
export AMIBERRY_HOME_DIR
export AMIBERRY_CONFIG_DIR

# Start pulseaudio for systems that need it (eg. if you have no sound at all)
#pulseaudio --system -D

# Just make sure these exist
mkdir -p "${volumes_path}" 2>/dev/null
mkdir -p "${var_path}" 2>/dev/null
mkdir -p "${uae_base_path}" 2>/dev/null


launch_amiberry()
{
    if [[ -f "${uae_config_path}/${1}.uae" ]]; then

        config_file="${uae_config_path}/${1}.uae"

    elif [[ -f "${refind_previousboot_file}" ]]; then

        # Read contents of file, use sed to strip non-ASCII
        boot_line=$(sed 's/[^[:print:]]//g' ${refind_previousboot_file})

        # Trim line to selection name
        launch_string=${boot_line#*: }
        launch_string=${launch_string#*Boot }
        launch_string=${launch_string%% from *}

        if [[ -f "${uae_config_path}/${launch_string}.uae" ]]; then

            config_file="${uae_config_path}/${launch_string}.uae"

        fi

    fi

    # If $config_file is undefined or doesn't exist, fallback to default if available
    if [[ ! -f "${config_file}" ]]; then

        if [[ -f "${uae_config_path}/default.uae" ]]; then

            config_file="${uae_config_path}/default.uae"

        fi

    fi


    if [[ -f "${config_file}" ]]; then

        # GGG It would be nice to be able to get an exit code or hint from the log file here
        # and shut down the PC if Amiberry was quit from within the guest (eg. AROS Wanderer menu > Shut down)
        write_log "Starting amiberry with config ${config_file}"

        amiberry -f "${config_file}" -s use_gui=no

    else

        write_log "Starting amiberry (no config)"

        amiberry

    fi

}

write_log "${application_name} ${application_version}"

# Clear caches
#rm "${var_path}/uae/hddir/*.uae" 2>/dev/null
rm "${var_path}/uae/dev/"*.uae 2>/dev/null

# Remove non-mounted directories in Volumes path
for dir in "${volumes_path}/"*/; do

    # Below check is required because loop runs once with wildcard on empty
    if [[ -d "${dir}" ]]; then

        if [[ ! $(grep "${dir%/}" /proc/mounts) ]]; then

            rm "${dir%/}.info" 2>>/dev/null
            rmdir "${dir%/}" 2>>/dev/null
            rm $(grep -l "${dir%/}" "${var_path}/uae/hddir/"*.uae ) 2>>/dev/null

        fi

    fi

done

# ..And any orphaned .info files
for file in "${volumes_path}/"*.info; do

    # Below check is required because loop runs once with wildcard on empty
    if [[ -f "${file}" ]]; then

        if [[ ! -d "${file%.info}" ]]; then

            rm "${file}" 2>>/dev/null

        fi

    fi

done



# Mount and catalog block devices
DD=0
DX=0

for dev in $(ls /dev/sd[a-z][1-9] 2>/dev/null); do

    mount_path=$(mount_device $dev $DD)
    ((DD++))

done

for dev in $(ls /dev/mmcblk[0-9]p[1-9] 2>/dev/null); do

    mount_path=$(mount_device $dev $DD)
    ((DD++))

done


# Allow /proc/mounts to catch up
sleep 0.5

for dev in $(ls /dev/sd[a-z] 2>/dev/null); do

    # Do not include mounted devices. Unmounted infers un-partitioned or RDB
    if [[ ! $(grep "${dev}" /proc/mounts) ]]; then

        # Check if the device is non-removable. Do not add removable devices (ie. empty card readers)
        if [[ $(lsblk -n -d -o RM ${dev}) -eq 0 ]]; then

            write_log "+DX${DX} ${dev} (unmounted)"

            mkdir -p "${var_path}/uae/dev" 2>/dev/null
            echo "hardfile2=rw,DX${DX}:${dev},0,0,0,512,0,,uae0" > "${var_path}/uae${dev}.${DX}.uae"
            echo "uaehf1=hdf,rw,DX${DX}:${dev},0,0,0,512,0,,uae0" >> "${var_path}/uae${dev}.${DX}.uae"

            ((DX++))
        fi
    fi
done

# Operation
# Mount anything that's mountable when amibootenv starts
# Mounted devices will be added to configs as directories
# Unmounted devices will be added to configs as hard drives
# The usb-watcher will maintain the mounts and update configs after emulation starts


# Start watches once
# NB the below would be nice but too difficult to check for another process with the same name and args
#/bin/bash "${my_path}/mount-handler.sh" "dev[a-z]" &
#/bin/bash "${my_path}/mount-handler.sh" "mmcblk[0-9]" "p" &

# Therefore use duplicate scripts
/bin/bash "${my_path}/usb-handler.sh" &
/bin/bash "${my_path}/mmc-handler.sh" &

/bin/bash "${my_path}/gw-handler.sh" &
/bin/bash "${my_path}/boot-handler.sh" watch &


# Main loop
while [[ 1 ]]; do

    . "${my_path}/update-configs.sh"

    if [[ -n $abe_amiberry_launch_delay ]]; then
        sleep $abe_amiberry_launch_delay 2>/dev/null
    fi

    launch_amiberry "${1}"

    clear

    # Calculate timeout action
    timeout_action=$abe_amiberry_exit_action
    unset shutdown_switch

    if [[ "${timeout_action}" == "shutdown" ]]; then
        shutdown_switch="h"
    elif [[ "${timeout_action}" == "reboot" ]]; then
        shutdown_switch="r"
    elif [[ "${timeout_action}" == "shutdown_on_clean" ]]; then
        # GGG dependency on log path
        if [[ $(tail -n 5 "${log_path}/amiberry.log" | grep -i "mapped_free") ]]; then
            shutdown_switch="h"
            timeout_action="shutdown"
        else
            timeout_action="respawn"
        fi
    else
        timeout_action="respawn"
    fi

    # Trim log files
    for file in "${log_path}/"*; do

        tail -n $abe_log_maxlines "${file}" > "${file}.tail"
        mv "${file}.tail" "$file"

    done

    echo "[E]dit ${application_name_cc} Options"
    echo "[T]erminal"
    echo "[R]estart"
    echo "[S]hutdown"

    i=${abe_amiberry_exit_timeout:-3}
    key=

    echo -en "\n${application_name} will ${timeout_action} in ${i}.."

    while [[ $i -gt 0 ]]; do
        read -n 1 -t 1 key

        if [[ $key == 't' ]]; then
            echo -e "\n\nDropping to terminal. Use 'exit' command to respawn.\n\n"
            exit
        elif [[ $key == 'r' ]]; then
            /sbin/shutdown -r now
        elif [[ $key == 's' ]]; then
            /sbin/shutdown -h now
        elif [[ $key == 'e' ]]; then
            unset shutdown_switch
            micro -colorscheme=material-tc -keymenu=true "${my_path}/options.sh"
            i=1
            clear
        fi

        ((i--))
        echo -en "\b\b\b${i}.."
    done

    if [[ -n $shutdown_switch ]]; then
        /sbin/shutdown -$shutdown_switch now
    fi

done






