#!/bin/bash

cat <<EOF >~/.local/share/applications/Docker.desktop
[Desktop Entry]
Version=1.0
Name=Docker
Comment=Manage Docker containers with LazyDocker
Exec=/home/$USER/.local/kitty.app/bin/kitty --config /home/$USER/.config/kitty/pane.conf --class=Docker --title=Docker lazydocker
Terminal=false
Type=Application
Icon=/home/$USER/.local/share/omakub/applications/icons/Docker.png
Categories=GTK;
StartupNotify=false
EOF
