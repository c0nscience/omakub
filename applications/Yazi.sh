#!/bin/bash

cat <<EOF >~/.local/share/applications/Yazi.desktop
[Desktop Entry]
Version=1.0
Name=Yazi
Comment=Browse files with Yazi
Exec=/home/$USER/.local/kitty.app/bin/kitty --config /home/$USER/.config/kitty/pane.conf --class=Yazi --title=Yazi yazi
Terminal=false
Type=Application
Icon=/home/$USER/.local/share/omakub/applications/icons/Yazi.png
Categories=GTK;
StartupNotify=false
EOF
