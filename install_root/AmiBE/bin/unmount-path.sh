# $1=/path/to/mountpoint

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"

max_attempts=5
attempts=0

while [[ -d "${1}" && $attempts -lt $max_attempts ]]; do

    sleep 0.5

    umount "${1}"

    sleep 0.5

    if [[ ! $(grep -F "${1}" /proc/mounts) ]]; then

        write_log "Unmount ${1}"

        rm "${1}.info" 2>>/dev/null
        rmdir "${1}" 2>>/dev/null
        rm $(grep -l "${1}" ${var_path}/uae/hddir/*.uae ) 2>>/dev/null

    fi

    ((attempts++))

done






