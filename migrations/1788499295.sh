#!/bin/bash

# Enable kitty remote control (`kitty @ ...`) for machines installed before
# kitty.conf gained allow_remote_control/listen_on. socket-only + listen_on
# scopes control to a kitty instance's own socket, and kitty exports
# KITTY_LISTEN_ON to processes running inside it, so `kitty @ ...` works from
# a shell in that window with no extra flags.
# kitty.conf includes theme/font/size, so re-copying it preserves the user's
# choices there, same as the 1783334259 kitty.conf refresh.
if [ -f ~/.config/kitty/kitty.conf ]; then
  cp $OMAKUB_PATH/configs/kitty/kitty.conf ~/.config/kitty/kitty.conf
fi
