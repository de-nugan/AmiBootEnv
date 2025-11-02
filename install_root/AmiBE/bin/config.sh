#!/bin/bash

# Config vars and common functions for amiboot scripts
# Paths should not end with a slash

release=1
application_version="0.4.2"

# Installation vars
application_name_cc="AmiBootEnv"
application_name_lc="amibootenv"
application_name="${application_name_cc}"
application_name_short="AmiBE"

base_path="/${application_name_short}"
application_path="${base_path}/bin"
volumes_path="${base_path}/Volumes"
icons_path="${base_path}/assets/icons"
var_path="${base_path}/var"
log_path="${var_path}/log"

uae_base_path="${base_path}/UAE"
uae_config_path="${uae_base_path}/conf"
adf_path="${uae_base_path}/floppies"
hdf_path="${uae_base_path}/harddrives"
rom_path="${uae_base_path}/roms"
cdrom_path="${uae_base_path}/cdroms"


# Local OS stuff
kernel_prefix="vmlinuz"
initrd_prefix="initrd.img"
efi_path="/boot/efi/EFI"
refind_previousboot_file="${efi_path}/refind/vars/PreviousBoot"


# Common functions #

write_log ()
{
    if [[ ! -d "${log_path}" ]]; then

        mkdir -p "${log_path}" 2>/dev/zero

    fi

    if [[ $# -gt 1 ]]; then

        echo "$(date +%y%m%d:%H%M%S) ${my_name} : ${2}" >> "${log_path}/${1}.log"

    else

        echo "$(date +%y%m%d:%H%M%S) ${my_name} : ${1}" >> "${log_path}/${application_name}.log"

    fi

    if [[ $debug ]]; then

        echo $*

    fi
}










