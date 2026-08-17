#!/bin/bash

# yazi ships only in the optional oxidise bundle (install/terminal/optional/
# app-oxidise.sh). Plant the app-grid launcher only when the binary is actually
# installed; otherwise remove any stale entry — so a machine without yazi never
# shows a launcher that opens a kitty window and immediately closes. This runs
# from the fresh-install glob, the yazi migrations, and app-oxidise.sh; the guard
# keeps the launcher's presence in sync with the binary on every one of them.
#
# Launched through `mise exec` because GNOME starts this entry with the session
# PATH, and mise's tools land on PATH only via `mise activate` — which
# defaults/bash/init skips in non-interactive shells, so GDM's login chain never
# runs it. yazi's bundled fzf plugin (`z`) spawns `fzf` with a bare execvp and no
# shell, so it inherits that PATH and dies with "Failed to start `fzf`"; fzf has
# had no system-wide location since it moved from apt to `mise use -g`
# (5d6b6da). `mise exec` is the non-shell equivalent of activate: same config,
# same env, nothing written to PATH. It needs no mise env itself — /usr/bin/mise
# is apt-installed and already on the session PATH. The `--` is required or mise
# reads `yazi` as a tool@version spec to install. The env carries into yazi's
# children, so the editor opener and any other tool it spawns get it too.
if command -v yazi &>/dev/null; then
  cat <<EOF >~/.local/share/applications/Yazi.desktop
[Desktop Entry]
Version=1.0
Name=Yazi
Comment=Browse files with Yazi
Exec=/home/$USER/.local/kitty.app/bin/kitty --config /home/$USER/.config/kitty/pane.conf --class=Yazi --title=Yazi mise exec -- yazi
Terminal=false
Type=Application
Icon=/home/$USER/.local/share/omakub/applications/icons/Yazi.png
Categories=GTK;
StartupNotify=false
EOF
else
  rm -f ~/.local/share/applications/Yazi.desktop
fi
