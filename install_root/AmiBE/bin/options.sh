# AmiBootEnv Options File

# Use BASH syntax, ie. no spaces, and everything is case sensitive!
# If using the default editor (Micro), save changes with Ctrl+S and exit with Ctrl+Q
# Lines that begin with a '#' are ignored.


# Default config
# Config to run when there's no fancy boot selector. This must match the name in Amiberry exactly.
#
abe_default_config=AROS


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
# By default, AmiBootEnv runs under SDL without Xorg. Xorg is an option because it may:
# - Present better RTG resolution options in hosted systems, especially for funky screen ratios or tiny pixels
# - Fix some performance issues on high res monitors
# But it comes with caveats:
# - Increased boot time
# - More difficult to scale emulation to full screen
# For best results under Xorg:
# - Native modes: Set display type to "Fullscreen" and set preferred resolution in Amiberry.
# - RTG: Set display type to "Windowed" in Amiberry, and set RTG resolution to match Xorg.
# Be prepared to experiment!
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

