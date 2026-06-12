#!/bin/bash

cat <<EOF >~/.local/share/applications/Activity.desktop
[Desktop Entry]
Version=1.0
Name=Activity
Comment=System activity from btop
Exec=/home/$USER/.local/kitty.app/bin/kitty --config /home/$USER/.config/kitty/btop.conf --class=Activity --title=Activity btop
Terminal=false
Type=Application
Icon=/home/$USER/.local/share/omakub/applications/icons/Activity.png
Categories=GTK;
StartupNotify=false
EOF
