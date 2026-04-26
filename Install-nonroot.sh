#!/bin/bash
# Run as root to install AmiBootEnv
# Modified version: Amiberry runs as dedicated non-root user
# Check for local installation archive. Download from github if required.
# Unpack to subdir / temp path to avoid overwriting this file!

my_name=${0##*/}
my_path=${0%/${my_name}}

application_name="AmiBootEnv"

base_path="/AmiBE"
uae_base_path="${base_path}/UAE"

# Dedicated user for running Amiberry (non-root)
amiberry_user="amiberry"

# Prelims

if [[ $(id -u) -ne 0 ]]; then
    echo "ERROR: This installer must be run as the true root user."
    exit 1
fi

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
    apt-get --assume-yes -qq --allow-downgrades install "${1}"
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
    package_version="${2}"

    if [[ -n "${package_version}" ]]; then

        debfile="./${package_name}_${package_version}_${arch}.deb"

        if [[ ! -f $debfile ]]; then

            zipfile="./${package_name}-v${package_version}-debian-${debian_codename}-${arch}.zip"

            if [[ ! -f $zipfile ]]; then

                wget_url="https://github.com/BlitterStudio/${package_name}/releases/download/v${package_version}/${package_name}-v${package_version}-debian-${debian_codename}-${arch}.zip"

                echo "Fetching ${package_name} installer from ${wget_url}"
                wget "${wget_url}"

            fi

            if [[ -f $zipfile ]]; then

                unzip -o $zipfile

            fi

        fi

    else

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

            fi

            debfile=$(ls -vr ./${package_name}_*${arch}.deb | head -1)

        fi
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
echo "This installer MUST be run as ROOT. ${application_name} will run as user '${amiberry_user}'."
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

    # Add contrib to sources.list
    sed -r -i 's/^deb(.*)$/deb\1 contrib/g' /etc/apt/sources.list
    apt-get update
    #apt-get upgrade

fi

install_package wget  # Not included in Debian aarch64
install_package unzip
install_package curl

# Enable root SSH login so installation files can be copied via SCP
install_package openssh-server
echo "Enabling root SSH login for file transfer..."
if grep -q "^#*PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi
systemctl restart ssh

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

# Patch scripts for non-root operation (add sudo to privileged commands)
echo "Patching scripts for non-root operation..."

# main.sh - use patched version that fixes exit menu and adds sudo
if [[ -f "${my_path}/main.sh" ]]; then
    echo "Installing patched main.sh (fixes Terminal/Options menu + sudo)..."
    cp "${my_path}/main.sh" "${base_path}/bin/main.sh"
else
    # Fallback to sed patches if patched file not found
    sed -i 's|/sbin/shutdown -r now|sudo /sbin/shutdown -r now|g' "${base_path}/bin/main.sh"
    sed -i 's|/sbin/shutdown -h now|sudo /sbin/shutdown -h now|g' "${base_path}/bin/main.sh"
fi

# mount-device-function.sh - mount command
sed -i 's|mount \$1 "\${volumes_path}/\${label}"|sudo mount \$1 "\${volumes_path}/\${label}"|g' "${base_path}/bin/mount-device-function.sh"

# unmount-device.sh - umount command
sed -i 's|umount "\${1}"|sudo umount "\${1}"|g' "${base_path}/bin/unmount-device.sh"

# unmount-path.sh - umount command
sed -i 's|umount "\${1}"|sudo umount "\${1}"|g' "${base_path}/bin/unmount-path.sh"

# boot-handler.sh - cp to EFI partition
sed -i 's|cp -f "\${boot_stanzas_file}" "\${efi_path}/refind/amiboot/"|sudo cp -f "\${boot_stanzas_file}" "\${efi_path}/refind/amiboot/"|g' "${base_path}/bin/boot-handler.sh"

# Ensure all scripts are executable
chmod +x "${base_path}/bin/"*.sh
chmod +x "${base_path}/bin/options_ex.sh"
# options_ex.sh is rewritten by config.sh on every run - must be writable
chmod u+w "${base_path}/bin/options_ex.sh"

# Install remaining packages
install_package plymouth
install_package plymouth-themes
install_package inotify-tools
install_package libegl1
install_package libgegl-common
install_package $(apt-cache pkgnames libgegl-0)
install_package alsa-utils
install_package micro
install_package sudo

# Experimental Xorg support
install_package xorg
install_package ratpoison

if [[ $debian_codename == "trixie" ]]; then

    # Additional packages required for Trixie
    install_package libgl1

fi

# Create dedicated amiberry user if it doesn't exist
if ! id "${amiberry_user}" &>/dev/null; then
    echo "Creating ${amiberry_user} user..."
    useradd -m -s /bin/bash \
        -G audio,video,input,plugdev,render,tty,dialout \
        "${amiberry_user}"

    # Set password for the new user
    echo ""
    echo "Please set a password for the '${amiberry_user}' user."
    echo "This password is needed for SSH access and sudo commands."
    echo ""
    passwd "${amiberry_user}"
else
    echo "User ${amiberry_user} already exists, ensuring group memberships..."
    usermod -a -G audio,video,input,plugdev,render,tty,dialout "${amiberry_user}"
fi

amiberry_home=$(getent passwd "${amiberry_user}" | cut -d: -f6)

# Create udev rules for direct hardware access
echo "Configuring udev rules for hardware access..."
cat > /etc/udev/rules.d/99-amiberry-input.rules << 'EOF'
# Allow input group access to event devices (joysticks, etc.)
SUBSYSTEM=="input", GROUP="input", MODE="0660"

# Allow video group access to framebuffer
SUBSYSTEM=="graphics", GROUP="video", MODE="0660"

# Allow access to USB HID devices (joysticks, gamepads)
SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", GROUP="plugdev", MODE="0660"
EOF

udevadm control --reload-rules
udevadm trigger

# Allow amiberry user to run privileged commands without password
echo "Configuring sudo permissions..."
cat > /etc/sudoers.d/amiberry << EOF
# Allow sudo without a TTY (required for systemd su -c context)
Defaults:${amiberry_user} !requiretty

# Allow amiberry user to shutdown and reboot
${amiberry_user} ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot, /usr/bin/systemctl poweroff, /usr/bin/systemctl halt
${amiberry_user} ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot, /sbin/poweroff

# Allow mount/umount for hot-pluggable storage
${amiberry_user} ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount

# Allow writing to EFI partition for boot menu updates
${amiberry_user} ALL=(ALL) NOPASSWD: /usr/bin/cp * /boot/efi/EFI/refind/amiboot/*

${amiberry_user} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/amiberry

# Validate sudoers file
if ! visudo -c -f /etc/sudoers.d/amiberry; then
    echo "WARNING: sudoers file validation failed, removing..."
    rm -f /etc/sudoers.d/amiberry
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

# Platform-specific customisations
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

elif [[ "${arch}" == "amd64" ]]; then

    # default.uae is not required as of 0.5.10
    #cp "${uae_base_path}/conf/AROS.uae" "${uae_base_path}/conf/default.uae"

    # Set GRUB timeout and enable bootsplash
    echo "EFI path not found. Setting GRUB defaults.."
    sed -i -r 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    sed -i -r 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet"/' /etc/default/grub

    /sbin/update-grub

elif [[ "${arch}" == "arm64" ]]; then

    # Enable splash screen for RPi
    install_package rpd-plym-splash
    sed -i /boot/firmware/cmdline.txt -e "s/$/ quiet splash plymouth.ignore-serial-consoles/"

fi


if [[ $(which plymouth-set-default-theme) ]]; then

    echo "Setting Plymouth default theme.."
    plymouth-set-default-theme -R amiboot

fi


# Now the main event - install Amiberries if required
# Using 8.1.5 - 8.x renderer issues are now resolved.
if [[ ! $(which amiberry) ]]; then

    install_amiberry_flavour amiberry "8.1.5"

fi

install_amiberry_flavour amiberry-lite "8.1.5"


if [[ $(which amiberry) || $(which amiberry-lite) ]]; then

    # Create required directories that may not exist in the archive
    mkdir -p "${base_path}/var/log"
    mkdir -p "${uae_base_path}/savestates"
    mkdir -p "${uae_base_path}/screenshots"

    # Set proper ownership - user owns the data, can write configs/saves
    echo "Setting ownership of ${base_path} to ${amiberry_user}..."
    chown -R "${amiberry_user}:${amiberry_user}" "${base_path}"
    chmod -R u+rwX,go+rX,go-w "${base_path}"

    # Ensure writable directories for saves, screenshots, logs
    chmod -R u+w "${base_path}/var"
    chmod -R u+w "${uae_base_path}/savestates"
    chmod -R u+w "${uae_base_path}/screenshots"
    chmod -R u+w "${uae_base_path}/conf"

    # Create config directories for the amiberry user
    mkdir -p "${amiberry_home}/.config/amiberry"
    mkdir -p "${amiberry_home}/.config/amiberry-lite"
    create_config_stub "${amiberry_home}/.config/amiberry/amiberry.conf"
    create_config_stub "${amiberry_home}/.config/amiberry-lite/amiberry.conf"
    chown -R "${amiberry_user}:${amiberry_user}" "${amiberry_home}/.config"

    # Also create system-wide config as fallback
    create_config_stub "${base_path}/UAE/conf/amiberry.conf"

    if [[ "${arch}" == "arm64" ]]; then

        if [[ $(which amiberry-lite) ]]; then

            # Set Amiberry-Lite as default for ARM
            sed -i 's/#abe_use_amiberry_lite=1/abe_use_amiberry_lite=1/' "${base_path}/bin/options.sh"
            # If this whole section is commented out, then an echo will prevent the script from stopping here
            echo

        fi

    fi

    # Configure systemd to run Amiberry directly on tty1 (bypasses login entirely)
    # This method only affects tty1 - SSH logins are unaffected
    echo "Configuring systemd getty override for tty1..."
    mkdir -p /etc/systemd/system/getty@tty1.service.d

    cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/su - ${amiberry_user} -c "${base_path}/bin/launch.sh"
StandardInput=tty
StandardOutput=tty
EOF

    # Limit virtual terminals to just tty1
    if [[ ! -f /etc/systemd/logind.conf.orig ]]; then
        cp /etc/systemd/logind.conf /etc/systemd/logind.conf.orig
    fi

    # Set NAutoVTs=1 in logind.conf
    if grep -q "^#*NAutoVTs=" /etc/systemd/logind.conf; then
        sed -i 's/^#*NAutoVTs=.*/NAutoVTs=1/' /etc/systemd/logind.conf
    else
        echo "NAutoVTs=1" >> /etc/systemd/logind.conf
    fi

    systemctl daemon-reload

    # Add handy access to boot icons
    if [[ -d /boot/efi/EFI/refind/amiboot/icons/ ]]; then

        mkdir -p "${base_path}/assets" 2>/dev/null
        ln -s /boot/efi/EFI/refind/amiboot/icons/ "${base_path}/assets/booticons" 2>/dev/null

    fi

    pushd "${base_path}/bin"
    "./boot-handler.sh"
    popd

    # boot-handler.sh sources config.sh which generates options_ex.sh as root.
    # Fix ownership and permissions so the amiberry user can write to it at runtime.
    chown "${amiberry_user}:${amiberry_user}" "${base_path}/bin/options_ex.sh"
    chmod u+rwx "${base_path}/bin/options_ex.sh"

    # Give boot-handler a moment to update..
    sleep 3

    echo
    echo "Installation appears to have been successful!"
    echo "Amiberry will run as user '${amiberry_user}' (not root)."
    echo
    echo "The systemd getty service on tty1 has been configured to launch Amiberry"
    echo "directly. SSH logins are unaffected and will get a normal shell."
    echo
    echo "NOTE: If any scripts call 'shutdown' or 'reboot' directly,"
    echo "      they should be changed to use 'sudo shutdown' or 'sudo reboot'."
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
