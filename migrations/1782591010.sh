#!/bin/bash

# The About/Activity/Docker/Omakub/Neovim apps used to open in alacritty (removed).
# Their kitty launchers reference popup configs (pane.conf/btop.conf + theme/font
# includes) that some installs never received. Deploy the popup configs (keep any
# existing theme/font choice) and regenerate every launcher so they open in kitty,
# sized for their content.
mkdir -p ~/.config/kitty
cp $OMAKUB_PATH/configs/kitty/pane.conf ~/.config/kitty/pane.conf
cp $OMAKUB_PATH/configs/kitty/btop.conf ~/.config/kitty/btop.conf
[ -f ~/.config/kitty/theme.conf ] || cp $OMAKUB_PATH/themes/tokyo-night/kitty.conf ~/.config/kitty/theme.conf
[ -f ~/.config/kitty/font.conf ] || cp $OMAKUB_PATH/configs/kitty/fonts/CaskaydiaMono.conf ~/.config/kitty/font.conf
[ -f ~/.config/kitty/font-size.conf ] || cp $OMAKUB_PATH/configs/kitty/font-size.conf ~/.config/kitty/font-size.conf

source $OMAKUB_PATH/applications/About.sh
source $OMAKUB_PATH/applications/Activity.sh
source $OMAKUB_PATH/applications/Docker.sh
source $OMAKUB_PATH/applications/Omakub.sh
source $OMAKUB_PATH/applications/Neovim.sh
