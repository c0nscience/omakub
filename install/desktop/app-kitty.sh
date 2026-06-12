#!/bin/bash

# Kitty is a GPU-powered terminal with a native graphics protocol. See https://sw.kovidgoyal.net/kitty/
# Installed via the official installer, not apt: noble's apt kitty (0.32) is
# 2+ years stale and lacks window_title_bar_* (needs >=0.47).
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

mkdir -p ~/.local/bin
ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/

# Desktop entry pointing at the self-contained install
mkdir -p ~/.local/share/applications
cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty.desktop
sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty.desktop

mkdir -p ~/.config/kitty
cp ~/.local/share/omakub/configs/kitty/kitty.conf ~/.config/kitty/kitty.conf
cp ~/.local/share/omakub/configs/kitty/pane.conf ~/.config/kitty/pane.conf
cp ~/.local/share/omakub/configs/kitty/btop.conf ~/.config/kitty/btop.conf
cp ~/.local/share/omakub/configs/kitty/tab_bar.py ~/.config/kitty/tab_bar.py
cp ~/.local/share/omakub/configs/kitty/focus_or_tab.py ~/.config/kitty/focus_or_tab.py
cp ~/.local/share/omakub/themes/tokyo-night/kitty.conf ~/.config/kitty/theme.conf
cp ~/.local/share/omakub/configs/kitty/fonts/CaskaydiaMono.conf ~/.config/kitty/font.conf
cp ~/.local/share/omakub/configs/kitty/font-size.conf ~/.config/kitty/font-size.conf

# notify-send (libnotify-bin) backs the desktop-notification hooks below
sudo apt install -y libnotify-bin

# Register Claude Code desktop-notification hooks (only if Claude Code is
# configured). The zellij tab-name capture that used to label these
# notifications went away with zellij; kitty has no cheap equivalent.
if [ -f "$HOME/.claude/settings.json" ] && command -v jq &>/dev/null; then
  if ! jq -e '.hooks.Stop' "$HOME/.claude/settings.json" &>/dev/null; then
    notify_attention='msg=$(jq -r ".message // \"needs your attention\""); notify-send -a "Claude Code" -u normal "Claude Code" "$msg" || true'
    notify_done='notify-send -a "Claude Code" -u low "Claude Code" "Finished responding" || true'
    tmp=$(mktemp)
    jq --arg notify_attention "$notify_attention" --arg notify_done "$notify_done" '
      .hooks += {
        Notification: [{ matcher: "", hooks: [{ type: "command", command: $notify_attention }] }],
        Stop:         [{ hooks: [{ type: "command", command: $notify_done }] }]
      }' "$HOME/.claude/settings.json" >"$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
  fi
fi

source ~/.local/share/omakub/install/desktop/set-kitty-default.sh
