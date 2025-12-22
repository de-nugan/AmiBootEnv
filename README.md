# AmiBootEnv README #

The goal of AmiBootEnv is to turn a PC into an Amiga, as simply and completely as practicable.

Several excellent options exist for this task already (Amikit, Amiga Forever, PiMIGA et al.) though they mainly focus on providing a slick, customised Workbench environment with plenty of software pre-installed.

AmiBootEnv's goal differs in that it is mainly focussed on providing a base (emulated) system on which to install and run your virtual Amiga(s). Consider it more as the machine itself, not the software.

AmiBootEnv was inspired by the rEFInd boot manager, Rob Smith's amazing FloppyBridge and my own obsession with putting an Amiga on everything.


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
    - Supported versions are 12 (bookworm) and 13 (trixie).
    - Use the netboot installer to save download time.
    - Installing in UEFI mode is highly recommended to make use of rEFInd boot manager integration.
    - Create a new parttition table (GPT) on the target disk. Boot integration only supports GPT-partitioned system disks. 
    - Include a root partition of at least 4 GB (bare minimal installation is already 1.8 GB), or just use Guided Partitioning => "Use entire disk"
    - At the package selection screen select Debian System Utilities only. ** Do not install an X Windows desktop environment! **
    - Select a local Debian mirror when prompted. This ensures software sources are configured. 
    - Please see Debian Linux documentation if required.
2. Boot and login as root.
3. Enter the commands below to download and run the Installer:

    wget https://raw.githubusercontent.com/de-nugan/AmiBootEnv/master/Install.sh

    bash ./Install.sh

4. READ the warning message, and follow the prompts to install. 
5. Select 'YES' to install rEFInd if prompted, and 'r' to reboot when complete.
6. On UEFI systems you should be greeted with the rEFInd boot selector with the following boot options:
    - Linux kernels. These can be hidden by selecting and hitting the delete key.
    - Included UAE configurations. Only AROS will boot unless Amiga ROMs are also imported (Amiga system ROMs are not included with AmiBootEnv).
7. Use the arrow keys to select AROS and hit ENTER. The system should boot into AROS runnning under Amiberry (m68k).
8. To import system ROMs or other files, copy to a USB drive and insert.
    - The USB drive should be accessible under the "Volumes:" drive in AROS.
    - Copy files from under "Volumes:" to the required locations in the "UAE:" drive.
    - The included A500 and A1200 configs will look for roms named kick13.rom and kick31.rom respectively. 
    - Hit F12 to open the Amiberry GUI, go to Paths and select "Rescan Paths" to include the new ROMs in Amiberry.


## Upgrading ##

1. Quit Amiberry and press 't' for terminal.
2. Remove previous installation files from /root/ directory:

    rm \*.\*

3. Repeat the wget and bash commands at Installation step 3. 

NB: This will overwrite options.h and the included Amiberry configs. Additional user configs should not be affected. 


## Amiberry Configuration ##

AmiBootEnv looks for pre-launch instructions in the Description field of the selected Amiberry configuration as follows:

#### HDD=DIR ####
Mount and add attached non-system block device partitions as directories (equivalent to the "Add Directory" option in UAE).

#### HDD=NATIVE ####
Add attached (unmounted) block devices as native drives (equivalent to the "Add Hard Drive" option in UAE).

#### HDD=AUTO ####
Add mountable non-system block device partitions as directories, and any non-mountable drives (eg. Amiga native or blank) as native drives.

#### DF0=GWA ####
Add Greaseweazle as DF0 if attached. Assume Greaseweazle has floppy connected to cable 'A' position (after twist). 
Drive number can be 0, 1, 2 or 3. GW cable pos can be A or B. Only a single physical drive is supported. 

#### BOOTICON=file.png ####
Include this configuration in the system boot menu using icon "file.png".


## Boot Icons ##

The following icons are included under /AmiBE/assets/booticons 

- os_amiga_lefty.png
- os_amiga_checkmark.png
- os_amiga_boing.png
- os_aros_kitty.png

Icons should be 128 x 128 PNG format with transparency.
Icon filenames must not contain spaces.


## WARNING! ##

I created AmiBootEnv for my personal use but am sharing in case it is useful for anyone else.

It is not a professional product and comes without any warranty of any kind!

AmiBootEnv and its installer run as root and have full access to your system!

AmiBootEnv can give any virtual Amiga full access to your PC's drives, this can easily lead to complete annihilation of your data!

Only install AmiBootEnv on a system that DOES NOT contain important data and IS NOT used for any other purpose!


###



