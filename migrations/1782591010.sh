#!/bin/bash

# The About app used to open in alacritty (removed) and now points at a kitty
# pane.conf that isn't sized for fastfetch. Regenerate its launcher so it opens
# in kitty at a window large enough to show the full fastfetch output.
source $OMAKUB_PATH/applications/About.sh
