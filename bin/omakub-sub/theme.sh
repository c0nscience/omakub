#!/bin/bash

THEME_NAMES=("Tokyo Night" "Catppuccin" "Nord" "Everforest" "Gruvbox" "Kanagawa" "Ristretto" "Rose Pine" "Matte Black")
THEME=$(gum choose "${THEME_NAMES[@]}" "<< Back" --header "Choose your theme" --height 12 | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

if [ -n "$THEME" ] && [ "$THEME" != "<<-back" ]; then
  cp $OMAKUB_PATH/themes/$THEME/kitty.conf ~/.config/kitty/theme.conf
  # kitty doesn't watch its config like alacritty did; signal a live reload
  pkill -USR1 -x kitty 2>/dev/null || true
  if [ -d "$HOME/.config/nvim" ]; then
    cp $OMAKUB_PATH/themes/$THEME/neovim.lua ~/.config/nvim/lua/plugins/theme.lua
  fi

  if [ -f "$OMAKUB_PATH/themes/$THEME/btop.theme" ]; then
    cp $OMAKUB_PATH/themes/$THEME/btop.theme ~/.config/btop/themes/$THEME.theme
    sed -i "s/color_theme = \".*\"/color_theme = \"$THEME\"/g" ~/.config/btop/btop.conf
  else
    sed -i "s/color_theme = \".*\"/color_theme = \"Default\"/g" ~/.config/btop/btop.conf
  fi

  source $OMAKUB_PATH/themes/$THEME/gnome.sh
  source $OMAKUB_PATH/themes/$THEME/tophat.sh
  source $OMAKUB_PATH/themes/$THEME/vscode.sh

  # Forgo setting the Chrome theme until we might find a less disruptive way of doing it.
  # Having to quit Chrome, and all Chrome-based apps, is too much of an inposition.
  # source $OMAKUB_PATH/themes/$THEME/chrome.sh
fi

source $OMAKUB_PATH/bin/omakub-sub/menu.sh
