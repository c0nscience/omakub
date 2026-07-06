#!/bin/bash

# Re-ship the Yazi launcher for machines that advanced past migration
# 1783077958 without ever running it — the same bare-`git pull` trap as the
# atuin (1783351508) and kitty (1783335459) catch-ups. The yazi migration was
# named 1783077958 but committed in ec947d6 (dated ~2 min later), and 4661f58
# landed ~20 min after that; once HEAD sat on a commit newer than the migration
# filename, migrate.sh recorded that date as "last applied" and skipped
# 1783077958 for good. Symptom: no Yazi.desktop in the app grid even though the
# yazi binary is present. Desktop-only (the launcher opens yazi in a kitty
# window); rewriting the .desktop is idempotent.
if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
  source $OMAKUB_PATH/applications/Yazi.sh
  command -v update-desktop-database &>/dev/null &&
    update-desktop-database ~/.local/share/applications 2>/dev/null
fi
