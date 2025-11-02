# $1=/dev/node_to_be_mounted

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"

max_attempts=5
attempts=0

# Options to get mount path
# /proc/mounts - accurate but spaces replaced with octal \040
# /etc/mtab - as above but a copy of the data?
# mount command - as above
# lsblk -o MOUNTPOINT - will not return any device info if the device has been removed (although it is still mounted)
# store in a file

mount_path=$(cat "${var_path}/${1}")

while [[ -d "${mount_path}" && $attempts -lt $max_attempts ]]; do

    sleep 0.5

    umount "${1}"

    sleep 0.5

    if [[ ! $(grep -F "${mount_path}" /proc/mounts) ]]; then

        write_log "Unmount ${1} => ${mount_path}"

        rm "${mount_path}.info" 2>>/dev/null
        rmdir "${mount_path}" 2>>/dev/null
        rm $(grep -l "${mount_path}" ${var_path}/uae/hddir/*.uae) 2>>/dev/null

    fi

    ((attempts++))

done






