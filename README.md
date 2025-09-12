# Amiboot README #

The goal of Amiboot is to turn a PC into an Amiga, as simply and completely as practicable.

Several excellent options exist for this task already (Amikit, Amiga Forever, PiMIGA et al.) though they mainly focus on providing a slick, customised Workbench environment with plenty of software pre-installed.

Amiboot's goal differs in that it is mainly focussed on providing a base (emulated) system on which to install and run your virtual Amiga(s). Consider it more as the machine itself, not the software.

Amiboot was inspired by the rEFInd boot manager, Rob Smith's amazing FloppyBridge and my own obsession with putting an Amiga on everything.


## Features ##

- Boots directly into emulation without an X Windows environment.
- Automatic mount / unmount of USB storage devices (available within emulation under "Volumes:").
- Detects Greaseweazle floppy drives before starting emulation.
- Detects hard drives (both directories and native devices) before starting emulation.
- Integrates the rEFInd boot manager on UEFI systems to provide an Amiga boot selector.
- Includes a basic AROS system with Directory Opus for importing ROMs, ADFs, HDFs etc. from removable storage "The Amiga Way".
- Based on Debian Linux and the excellent Amiberry emulator.


## Installation ##

1. Install a minimal Debian x86_64 (amd64) system
    - SUpported Debian releases are 12 Bookworm and 13 Trixie.
    - Installing in UEFI mode is highly recommended to make use of rEFInd boot manager integration.
    - Include a root partition of at least 4 GB (bare minimal installation is already 1.8 GB), or just use Guided Partitioning => "Use entire disk"
    - Optional: Add a third /Amiga partition to store the amiboot system files. exFAT filesystem is recommended if installing to removable media to allow easy file management from any PC.
    - At the package selection screen select Debian System Utilities only. ** Do not install an X Windows environment! **
    - Select a local Debian package mirror when prompted (otherwise APT sources may be empty).
    - Please see Debian Linux documentation if required.
3. Boot and login as root
4. Download the Amiboot self-extracting installer, eg. with wget (check latest release for current download URL):
    - wget https://github.com/de-nugan/amiboot/releases/download/0.4.0/amiboot-debian-amd64.run
5. Run the installer (this will take a few minutes and produce a lot of messages):
    - chmod +x amiboot-debian-amd64.zip
    - ./amiboot-debian-amd64.zip
6. Once complete, reboot:
    - shutdown -r now (or hit the power button)
7. On UEFI systems you should be greeted with the rEFInd boot selector with the following boot options:
    - Linux kernels. These can be hidden by selecting and hitting the delete key.
    - Included UAE configurations. Only AROS will boot unless Amiga ROMs are also imported (Amiga system ROMs are not included with Amiboot).
8. Use the arrow keys to select AROS and hit ENTER. The system should boot into AROS runnning under Amiberry (m68k).
9. To import system ROMs or other files, copy to a USB drive and insert.
    - The USB drive should be accessible under the "Volumes:" drive in AROS.
    - Open Directory Opus and copy files from under "Volumes:" to the required locations in the "Amiboot:" drive.
    - Hit F12 to open the Amiberry GUI, go to Paths and select "Rescan Paths" to include the new ROMs in Amiberry.


## Amiberry Configuration ##

Amiboot looks for pre-launch instructions in the Description field of the selected Amiberry configuration as follows:

#### HDD=DIR ####
Mount and add attached non-system block device partitions as directories (equivalent to the "Add Directory" option in UAE).

#### HDD=NATIVE ####
Add attached (unmounted) block devices as native drives (equivalent to the "Add Hard Drive" option in UAE).

#### HDD=AUTO ####
Add mountable non-system block device partitions as directories, and any non-mountable drives (eg. Amiga native or blank) as native drives.

#### GW=A0 ####
Add Greaseweazle as DF0: if detected. Greaseweazle has floppy connected on cable in 'A' postiion (after twist). Drive number can be 0, 1, 2 or 3.

#### GW=B0 ####
Add Greaseweazle as DF0: if detected. Greaseweazle has floppy connected on cable in 'B' postiion (no twist). Drive number can be 0, 1, 2 or 3.

#### BOOTICON=file.png ####
Include this configuration in the system boot menu using icon "file.png". Valid icon files are stored in /boot/efi/EFI/refind/amiboot/icons/.


## Boot Icons ##

The following icons are included under /boot/efi/EFI/refind/amiboot/icons

- os_amiga_lefty.png
- os_amiga_checkmark.png
- os_amiga_boing.png
- os_aros_kitty.png

Icons should be 128 x 128 PNG format with transparency.
Icon filenames must not contain spaces.


## Warning! ##

I created Amiboot for my personal use but am sharing in case it is useful for anyone else.

It is not a professional product and comes without any warranty of any kind!

Amiboot and its installer run as root and have full access to your system!

Amiboot can give any virtual Amiga full access to your PC's drives, this can easily lead to complete annihilation of your data!

Only install Amiboot on a system that DOES NOT contain important data and IS NOT used for any other purpose!


###



