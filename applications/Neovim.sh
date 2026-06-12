#!/bin/bash

cat <<EOF >~/.local/share/applications/Neovim.desktop
[Desktop Entry]
Version=1.0
Name=Neovim
Comment=Edit text files
Exec=/home/$USER/.local/kitty.app/bin/kitty --config /home/$USER/.config/kitty/pane.conf --class=Neovim --title=Neovim nvim %F
Terminal=false
Type=Application
Icon=nvim
Categories=Utilities;TextEditor;
StartupNotify=false
EOF
