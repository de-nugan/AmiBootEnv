# .xinitrc for AmiBootEnv

# Xorg setup
/AmiBE/bin/xsetup.sh

# Start AmiBE
# The second arg is required to keep xterm open after Amiberry exits
/usr/bin/X11/xterm -e "/AmiBE/bin/main.sh;/bin/bash"
