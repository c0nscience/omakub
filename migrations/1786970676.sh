#!/bin/bash

# Re-ship the Yazi launcher so it starts yazi under `mise exec`. Without it the
# app-grid entry inherits GNOME's session PATH, which has no mise tools (mise
# activate is interactive-only), and yazi's fzf plugin fails to spawn `fzf`.
# Desktop-only; rewriting the .desktop is idempotent.
if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
  source $OMAKUB_PATH/applications/Yazi.sh
  command -v update-desktop-database &>/dev/null &&
    update-desktop-database ~/.local/share/applications 2>/dev/null
fi
