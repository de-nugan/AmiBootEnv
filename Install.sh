#!/bin/bash
# Run as root to install AmiBootEnv
# Check for local installation archive. Download from github if required.
# Unpack to subdir / temp path to avoid overwriting this file!

my_name=${0##*/}
my_path=${0%/${my_name}}

application_name="AmiBootEnv"

base_path="/AmiBE"
uae_base_path="${base_path}/UAE"

# Prelims

unset arch

case $(uname -m) in
    "x86_64") arch=amd64 ;;
    "aarch64") arch=arm64 ;;
esac

if [[ ! -v arch ]]; then
    echo "This architecture is not supported."
    exit
fi


debian_version=$(cat /etc/debian_version)
major_version=${debian_version%%.*}

unset debian_codename

case $major_version in
    12) debian_codename=bookworm ;;
    13) debian_codename=trixie ;;
esac

if [[ ! -v debian_codename ]]; then
    echo "This OS is not supported."
    exit
fi

# Function defs

install_package ()
{
    echo "Installing ${1}.."
    #write_log install "Installing package ${1}"
    apt-get --assume-yes -qq install $1
}

create_config_stub ()
{
    echo "write_logfile=yes" > $1
    echo "rctrl_as_ramiga=yes" >> $1
    echo "disable_shutdown_button=no" >> $1
    echo "gui_theme=Default.theme" >> $1
    echo "config_path=${uae_base_path}/conf/" >> $1
    echo "retroarch_config=${uae_base_path}/conf/retroarch.cfg" >> $1
    echo "whdload_arch_path=${uae_base_path}/lha/" >> $1
    echo "floppy_path=${uae_base_path}/floppies/" >> $1
    echo "harddrive_path=${uae_base_path}/harddrives/" >> $1
    echo "cdrom_path=${uae_base_path}/cdroms/" >> $1
    echo "logfile_path=${base_path}/var/log/amiberry.log" >> $1
    echo "rom_path=${uae_base_path}/roms/amiberry/" >> $1
    echo "rp9_path=${uae_base_path}/rp9/" >> $1
    echo "savestate_dir=${uae_base_path}/savestates/" >> $1
    echo "screenshot_dir=${uae_base_path}/screenshots/" >> $1
}

install_amiberry_flavour ()
{
    # package_name must be amiberry or amiberry-lite
    package_name=${1:-"amiberry"}
    debfile=$(ls -vr ./${package_name}_*${arch}.deb | head -1)

    if [[ ! -f $debfile ]]; then

        zipfile=$(ls -vr ./${package_name}-v*${arch}.zip | head -1)

        if [[ ! -f $zipfile ]]; then

            wget_url=$(curl -s https://api.github.com/repos/BlitterStudio/${package_name}/releases/latest | grep browser_download_url.*debian-${debian_codename}-${arch} | cut -d : -f 2,3 | tr -d " \"")
            echo "Fetching ${package_name} installer from ${wget_url}"

            wget "${wget_url}"

            zipfile=$(ls -vr ./${package_name}-v*${arch}.zip | head -1)

        fi

        if [[ -f $zipfile ]]; then

            unzip -o $zipfile

        else

            echo "${package_name} download failed."

        fi

        debfile=$(ls -vr ./${package_name}_*${arch}.deb | head -1)

    fi

    if [[ -f $debfile ]]; then

        install_package "${debfile}"

    else

        echo "${package_name} installer not found! Please download and install manually."

    fi
}


# Installation

cat 1>&2 << 'EOB'

      ///   _              _ ____              _   _____
     ///   / \   _ __ ___ (_) __ )  ___   ___ | |_| ____|_ ____   __
    ///   / _ \ | '_ ` _ \| |  _ \ / _ \ / _ \| __|  _| | '_ \ \ / /
\\\///   / ___ \| | | | | | | |_) | (_) | (_) | |_| |___| | | \ V /
 \///   /_/   \_\_| |_| |_|_|____/ \___/ \___/ \__|_____|_| |_|\_/


EOB

echo "WARNING!"
echo
echo "${application_name} should ONLY be installed on a clean, minimal Debian Linux system."
echo "Do not install ${application_name} onto a system that contains important data or is used for any other purpose."
echo "Installing ${application_name} may lead to total annihilation of any data on this system."
echo "${application_name} is free software and is offered without any warranty of any kind."
echo
echo "This installer and ${application_name} both must run as root."
echo
echo -n "Proceed with installation? (Y/N) : "

read answer

if [[ $answer != "y" && $answer != "Y" ]]; then

    echo "Bye!"
    exit

fi

# Install prereqs

# Add contrib repo
if [[ ! $(grep -E "^deb .* contrib" /etc/apt/sources.list) ]]; then

    #write_log install "Adding contrib to /etc/apt/sources.list"
    sed -r -i 's/^deb(.*)$/deb\1 contrib/g' /etc/apt/sources.list
    apt-get update

fi

install_package wget  # Not included in Debian aarch64
install_package unzip
install_package curl

# Locate installation files / archive

pushd "${my_path}"

archive_ext="zip"

unset install_source_path

if [[ -f "${my_path}/install_root/AmiBE/bin/config.sh" ]]; then

    install_source_path="${my_path}/install_root"

else

    install_archive=$(ls -vr "${application_name}"*.${archive_ext} 2>/dev/null | head -1)

    if [[ ! -f "${install_archive}" ]]; then

        current_version=$(curl -s https://api.github.com/repos/de-nugan/${application_name}/releases/latest | grep tag_name | cut -d : -f 2,3 | tr -d " ,\"")

        archive_url="https://github.com/de-nugan/${application_name}/archive/refs/tags/${current_version}.${archive_ext}"

        install_archive="${application_name}-${current_version}.${archive_ext}"

        wget -O "${install_archive}" "${archive_url}"

    fi

    if [[ -f "${install_archive}" ]]; then

        mkdir -p "/var/tmp" 2>/dev/null
        unzip -oq "${install_archive}" -d "/var/tmp/"

    fi

    if [[ -f "/var/tmp/${install_archive%.${archive_ext}}/install_root/AmiBE/bin/config.sh" ]]; then

        install_source_path="/var/tmp/${install_archive%.${archive_ext}}/install_root"

    fi

fi

if [[ ! -v install_source_path ]]; then

    echo "INSTALLATION FAILED :("
    echo "A local installation archive could not be found."
    echo "Installation archive download failed."
    echo
    echo "Please ensure you have a working intenet connection."
    echo "Alternatively, download the install archive to this path and try again."

    exit

fi

# Install files
cp -R "${install_source_path}/AmiBE" /
cp -R "${install_source_path}/etc" /
cp -R "${install_source_path}/usr" /
cp -R "${install_source_path}/root" /

# Install remaining packages
install_package plymouth
install_package plymouth-themes
install_package inotify-tools
install_package libegl1
install_package libgegl-common
install_package $(apt-cache pkgnames libgegl-0)
install_package alsa-utils
install_package micro

# Experimental Xorg support
install_package xorg
install_package ratpoison

if [[ $debian_codename == "trixie" ]]; then

    # Additional packages required for Trixie
    install_package libgl1

fi

# Unmute analog audio Master out
amixer sset Master 80% unmute

for archive in "${uae_base_path}/harddrives/"*.zip; do

    extract_dir=${archive##*/}
    extract_dir=${extract_dir%.zip}

    if [[ ! -d "${uae_base_path}/harddrives/${extract_dir}" ]]; then

        unzip -q "${archive}" -d "${uae_base_path}/harddrives/"

    fi

done

# Check for EFI System Partition and install rEFInd if found
if [[ -d "/boot/efi/EFI" ]]; then

    if [[ ! $(dpkg -l | grep -i "refind") ]]; then

        echo "EFI path found. Installing rEFInd.."
        install_package refind

    fi

    refind_config_file="/boot/efi/EFI/refind/refind.conf"

    if [[ ! $(grep "${application_name}" "${refind_config_file}") ]]; then

        echo "" >> "${refind_config_file}"
        echo "# Added by ${application_name}" >> "${refind_config_file}"
        echo "include amiboot\\amiboot.conf" >> "${refind_config_file}"
        echo "include amiboot\\boot.conf"  >> "${refind_config_file}"

    fi

    # Install boot theme and config
    cp -R "${install_source_path}/boot" /

    # Patch with RefindPlus due to tools line bug in rEFInd
    wget_url=$(curl -s https://api.github.com/repos/RefindPlusRepo/RefindPlus/releases/latest | grep browser_download_url.* | cut -d : -f 2,3 | tr -d " \"")
    wget "${wget_url}"
    refindplus_zipfile=$(ls -vr ./*RefindPlus*.zip | head -1)

    if [[ -f $refindplus_zipfile ]]; then

        unzip -o $refindplus_zipfile

        if [[ -f "${refindplus_zipfile%.zip}/x64_RefindPlus_REL.efi" ]]; then

            mv /boot/efi/EFI/refind/refind_x64.efi /boot/efi/EFI/refind/refind_x64.efi.orig
            cp "${refindplus_zipfile%.zip}/x64_RefindPlus_REL.efi" /boot/efi/EFI/refind/refind_x64.efi

            # Fix the graphics mode bootsplash icon
            cp /usr/share/plymouth/themes/amiboot/zzz.png /boot/efi/EFI/refind/icons/os_debian.png

        fi

    fi

elif [[ $arch == "amd64" ]]; then

    # Otherwise create an initial default config
    echo "EFI path not found. Setting GRUB and launcher defaults.."
    cp "${uae_base_path}/conf/AROS.uae" "${uae_base_path}/conf/default.uae"

    # Set GRUB timeout and enable bootsplash
    sed -i -r 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    sed -i -r 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet"/' /etc/default/grub

    /sbin/update-grub

fi


if [[ $(which plymouth-set-default-theme) ]]; then

    echo "Setting Plymouth default theme.."
    plymouth-set-default-theme -R amiboot

fi


# Now the main event - install Amiberries if required
if [[ ! $(which amiberry) ]]; then

    install_amiberry_flavour amiberry

fi

if [[ ! $(which amiberry-lite) ]]; then

    install_amiberry_flavour amiberry-lite

fi


if [[ $(which amiberry) || $(which amiberry-lite) ]]; then

    # Now using roms matched to AROS HD image. Different versions may break AROS.
    # cp -r /usr/share/amiberry/roms/* "${rom_path}/"

    chmod -R 777 "${base_path}"

    mkdir -p "/root/.config/amiberry"
    mkdir -p "/root/.config/amiberry-lite"
    create_config_stub "/root/.config/amiberry/amiberry.conf"
    create_config_stub "/root/.config/amiberry-lite/amiberry.conf"
    create_config_stub "${base_path}/UAE/conf/amiberry.conf"

    if [[ $arch == "arm64" ]]; then

        # Set Amiberry-Lite as default for ARM
        # GGG Removed due to AROS boot issues on amiberry-lite 5.9.1
        echo
        #sed -i 's/#abe_use_amiberry_lite=1/abe_use_amiberry_lite=1/' "${base_path}/bin/options.sh"

    fi

    if [[ ! $(grep "${base_path}/bin/launch.sh" /root/.profile) ]]; then

        # Warning. Running from profile as new process (&) may be nice but will break ctrl+c to exit
        echo "" >> /root/.profile
        echo "# Added by ${application_name}" >> /root/.profile
        echo "clear" >> /root/.profile
        echo "${base_path}/bin/launch.sh" >> /root/.profile

    fi

    # Suppress login message
    touch /root/.hushlogin 2>/dev/null

    # Add handy access to boot icons
    if [[ -d /boot/efi/EFI/refind/amiboot/icons/ ]]; then

        mkdir -p "${base_path}/assets" 2>/dev/null
        ln -s /boot/efi/EFI/refind/amiboot/icons/ "${base_path}/assets/booticons" 2>/dev/null

    fi

    pushd "${base_path}/bin"
    "./boot-handler.sh"
    popd

    # Give boot-handler a moment to update?
    sleep 3

    echo
    echo "Installation appears to have been successful!"
    echo
    read -p "Press r to reboot, or any other key to exit. " -n 1 answer
    echo

    if [[ $answer == "r" || $answer == "R" ]]; then

        /sbin/shutdown -r now

    fi

else

    #write_log install "Amiberry not found. Installation did not complete successfully."
    echo "Amiberry not found. Installation did not complete successfully. Damn!"

fi


