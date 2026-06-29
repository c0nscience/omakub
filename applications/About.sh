#!/bin/bash

cat <<EOF >~/.local/share/applications/About.desktop
[Desktop Entry]
Version=1.0
Name=About
Comment=System information from Fastfetch
Exec=/home/$USER/.local/kitty.app/bin/kitty --config /home/$USER/.config/kitty/pane.conf -o remember_window_size=no -o initial_window_width=120c -o initial_window_height=36c --class=About --title=About bash -c 'fastfetch; read -n 1 -s'
Terminal=false
Type=Application
Icon=/home/$USER/.local/share/omakub/applications/icons/Ubuntu.png
Categories=GTK;
StartupNotify=false
EOF
