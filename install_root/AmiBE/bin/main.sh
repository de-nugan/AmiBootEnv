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

# Exit menu options
exit_menu_file="${var_path}/exit_menu"
menu_item_respawn="(A)miberry"
menu_item_options="(E)dit ${application_name_cc} Options"
menu_item_terminal="(T)erminal"
menu_item_reboot="(R)eboot"
menu_item_shutdown="(S)hutdown"

# Just make sure these exist
mkdir -p "${volumes_path}" 2>/dev/null
mkdir -p "${var_path}" 2>/dev/null
mkdir -p "${uae_base_path}" 2>/dev/null


launch_amiberry()
{
    # Find the config
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

    elif [[ $abe_use_postboot_selector ]]; then

        # Build systems selection menu
        systems_list_file="${var_path}/systems_list"
        rm "${systems_list_file}" 2>/dev/null

        for file in "${uae_config_path}/"*.uae; do
            if [[ $(grep -i "BOOTICON=" $file) ]]; then
                filename=${file##*/}
                echo ${filename%.uae} >> "${systems_list_file}"
            fi
        done

        . "${my_path}/abe-menu.sh" "${systems_list_file}" $abe_postboot_selector_timeout

        config_file="${uae_config_path}/${abe_menu_selection}.uae"

    elif [[ -f "${uae_config_path}/${abe_default_config}.uae" ]]; then

        config_file="${uae_config_path}/${abe_default_config}.uae"

    fi

    # If $config_file is undefined or doesn't exist, fallback to default if available
    if [[ ! -f "${config_file}" ]]; then

        if [[ -f "${uae_config_path}/default.uae" ]]; then

            config_file="${uae_config_path}/default.uae"

        fi

    fi

    # Set the binary
    if [[ ${abe_use_amiberry_lite} ]]; then

        amiberry=amiberry-lite

    else

        amiberry=amiberry

    fi

    write_log "Starting ${amiberry} with config [${config_file}]"

    if [[ -f "${config_file}" ]]; then

        $amiberry -f "${config_file}" -s use_gui=no

    else

        $amiberry

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

    echo $menu_item_respawn > "${exit_menu_file}"
    echo $menu_item_options >> "${exit_menu_file}"
    echo $menu_item_terminal >> "${exit_menu_file}"
    echo $menu_item_reboot >> "${exit_menu_file}"
    echo $menu_item_shutdown >> "${exit_menu_file}"

    if [[ "${abe_amiberry_exit_action}" == "shutdown" ]]; then
        echo $menu_item_shutdown > "${exit_menu_file}.selection"
    elif [[ "${abe_amiberry_exit_action}" == "reboot" ]]; then
        echo $menu_item_reboot > "${exit_menu_file}.selection"
    elif [[ "${abe_amiberry_exit_action}" == "shutdown_on_clean" ]]; then
        # GGG dependency on log path
        if [[ $(tail -n 5 "${log_path}/amiberry.log" | grep -i "mapped_free") ]]; then
            echo $menu_item_shutdown > "${exit_menu_file}.selection"
        else
            echo $menu_item_respawn > "${exit_menu_file}.selection"
        fi
    else
        echo $menu_item_respawn > "${exit_menu_file}.selection"
    fi

    # Trim log files
    for file in "${log_path}/"*; do
        tail -n $abe_log_maxlines "${file}" > "${file}.tail"
        mv "${file}.tail" "$file"
    done

    # Run the menu
    . "${my_path}/abe-menu.sh" "${exit_menu_file}" ${abe_amiberry_exit_timeout:-3}

    if [[ "${abe_menu_selection}" == "${menu_item_terminal}" ]]; then
        clear
        echo -e "\n\nDropping to terminal. Use 'exit' command to respawn.\n\n"
        exit
    elif [[ "${abe_menu_selection}" == "${menu_item_reboot}" ]]; then
        /sbin/shutdown -r now
    elif [[ "${abe_menu_selection}" == "${menu_item_shutdown}" ]]; then
        /sbin/shutdown -h now
    elif [[ "${abe_menu_selection}" == "${menu_item_options}" ]]; then
        micro -colorscheme=material-tc -keymenu=true "${my_path}/options.sh"
        clear
    fi

done






