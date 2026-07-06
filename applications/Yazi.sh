#!/bin/bash

# yazi ships only in the optional oxidise bundle (install/terminal/optional/
# app-oxidise.sh). Plant the app-grid launcher only when the binary is actually
# installed; otherwise remove any stale entry — so a machine without yazi never
# shows a launcher that opens a kitty window and immediately closes. This runs
# from the fresh-install glob, the yazi migrations, and app-oxidise.sh; the guard
# keeps the launcher's presence in sync with the binary on every one of them.
if command -v yazi &>/dev/null; then
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
else
  rm -f ~/.local/share/applications/Yazi.desktop
fi
