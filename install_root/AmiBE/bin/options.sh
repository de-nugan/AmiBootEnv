# AmiBootEnv Options File

# Use BASH syntax, ie. no spaces, and everything is case sensitive!
# If using the default editor (Micro), save changes with Ctrl+S and exit with Ctrl+Q
# Lines that begin with a '#' are ignored.


# Default action when Amiberry exits
# Valid options are: respawn, reboot, shutdown, shutdown_on_clean
# shutdown_on_clean will attempt to confirm Amiberry exited cleanly before shutting down, otherwise respawn if it crashed.
# This can be used to shutdown the PC from any hosted system that can close Amiberry, eg AROS.
# Default action is respawn
#
abe_amiberry_exit_action=respawn


# Timout counter when Amiberry exits (seconds)
# After timeout lapses, perform exit action
#
abe_amiberry_exit_timeout=3


# Amiberry launch delay (seconds)
# Delay launching Amiberry after updating configs. May be useful for troubleshooting.
#
#abe_amiberry_launch_delay=0


# Log file max lines
# Truncate log files longer than max lines when Amiberry exits.
#
abe_log_maxlines=2000


# Run Amiberry under Xorg (requires restart)
# This can fix some performance issues on high res monitors, but can make it harder to scale emulation to full screen.
# For best results set display type to "Fullscreen" for native modes and "Windowed" for RTG in Amiberry.
#
#abe_use_xorg=1


# Set a preferred Xorg screen mode if lower than the native mode.
# Performance at 4K and above may be poor, so lower res may help.
# Below are example modes. Run xrandr in X terminal to see valid modes for your display.
#
#abe_xorg_mode=1920x1080
#abe_xorg_mode=1280x720
#abe_xorg_mode=1280x1024
#abe_xorg_mode=1024x768


# Set the xrandr output here if the above resolution is not being set correctly.
# AmiBootEnv will default to the primary output if connected, otherwise the first connected output.
# Run xrandr in X terminal to see available outputs.
# Eg. abe_xrandr_output=HDMI-1
#
#abe_xrandr_output=

