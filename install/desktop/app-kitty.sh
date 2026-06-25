#!/bin/bash

# Kitty is a GPU-powered terminal with a native graphics protocol. See https://sw.kovidgoyal.net/kitty/
# Installed via the official installer, not apt: noble's apt kitty (0.32) is
# 2+ years stale and lacks window_title_bar_* (needs >=0.47).
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

mkdir -p ~/.local/bin
ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/

# Ubuntu's fonts-noto-color-emoji is CBDT-bitmap-only, which kitty's font
# scanner cannot see (symbol_map + emoji fallback silently fail). Install the
# scalable COLRv1 build user-level; kitty >=0.40 renders COLRv1 natively.
if [ ! -f ~/.local/share/fonts/Noto-COLRv1.ttf ]; then
  mkdir -p ~/.local/share/fonts
  curl -sL -o ~/.local/share/fonts/Noto-COLRv1.ttf \
    https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/Noto-COLRv1.ttf
  fc-cache -f ~/.local/share/fonts
fi

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

source ~/.local/share/omakub/install/desktop/set-kitty-default.sh
