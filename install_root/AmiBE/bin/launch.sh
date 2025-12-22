#!/bin/bash
clear

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"

# amixer sset Master 80% unmute

if [[ $abe_use_xorg ]]; then

    startx

else

    /AmiBE/bin/main.sh

fi


