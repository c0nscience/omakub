#!/bin/bash

# Catch-up migration: several copied configs drifted from their templates
# because no migration re-deployed them after the source files changed. Each
# step below is safe to re-run and refreshes only what a machine already has.

# Claude Code statusline. The one refresh migration (1780567330) was guarded on
# the statusline already being present, and statusline.sh changed three times
# since (cwd + token usage, 5-hour session + usage colors, model/effort colors).
# Re-sourcing the installer refreshes machines that have it and installs it on
# ones from before it existed (pre-June-2).
source $OMAKUB_PATH/install/terminal/claude-statusline.sh

# Kitty configs. app-kitty.sh deploys kitty.conf and tab_bar.py, but the only
# re-copy since the June switch (1782591010) covered pane.conf/btop.conf. Stale
# on machines already running kitty: scrollback-in-neovim + line numbers, the
# emoji-clock unmap and window switching (kitty.conf), and pane-driven tab
# naming (tab_bar.py). kitty.conf includes theme/font/size, so the user's theme
# and font choices survive the copy. Only refresh where kitty is deployed.
if [ -f ~/.config/kitty/kitty.conf ]; then
  cp $OMAKUB_PATH/configs/kitty/kitty.conf ~/.config/kitty/kitty.conf
  cp $OMAKUB_PATH/configs/kitty/tab_bar.py ~/.config/kitty/tab_bar.py
fi

# Regenerate desktop launchers whose deployed .desktop files drifted, only where
# already present: 9to5 (updated June 25, never re-emitted) and About (its June
# 29 fix was an in-place edit to already-shipped migration 1782591010, so anyone
# who pulled in the June 27-29 window never received it).
[ -f ~/.local/share/applications/9to5.desktop ] && source $OMAKUB_PATH/applications/9to5.sh
[ -f ~/.local/share/applications/About.desktop ] && source $OMAKUB_PATH/applications/About.sh
