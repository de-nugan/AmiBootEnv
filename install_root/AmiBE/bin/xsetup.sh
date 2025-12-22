#!/bin/bash
# Setup Xorg for AmiBE. Call from ~/.xinitrc

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"

# Start window manager
ratpoison &

# Set preferred screen mode
if [[ $abe_xorg_mode ]]; then

    output=$abe_xrandr_output

    if [[ -z $output ]]; then

        output_line=$(xrandr | grep -i " connected pri")

        if [[ -z $output_line ]]; then

            output_line=$(xrandr | grep -i " connected ")

        fi

        output=${output_line%% *}

    fi

    if [[ $output ]]; then

        write_log "Setting Xorg output ${output} to ${abe_xorg_mode}.."
        xrandr --output $output --mode $abe_xorg_mode

    fi

fi

