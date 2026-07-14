#!/bin/bash

# Re-ship statusline.sh to pick up the 5h-usage fix (1be7492). The API sends
# rate_limits.five_hour.used_percentage as a float (72.5), but the old guard
# matched on ^[0-9]+$, so the segment was silently dropped for every real value
# — nobody has ever seen the usage percent in their status line. A bare
# `git pull` is not enough on its own here: claude-statusline.sh copies the
# script to ~/.claude/statusline-command.sh at install time, and that installer
# only re-runs from the Install menu, so the deployed copy would keep the bug.
#
# Deliberately a plain copy rather than `source claude-statusline.sh` — the
# installer opens with `sudo apt install -y jq`, which would prompt for a
# password on an otherwise passwordless update just to no-op on a package that
# is already there. settings.json already points at this path, so refreshing the
# file is the whole job.
#
# Guarded on the deployed copy existing: if it does, the installer has run and
# jq is present. Idempotent — re-copying an already-fixed script changes nothing.
statusline="$HOME/.claude/statusline-command.sh"
if [ -f "$statusline" ]; then
  cp "$OMAKUB_PATH/configs/claude/statusline.sh" "$statusline"
  chmod +x "$statusline"
  echo "Updated Claude Code status line (5h usage percent now renders)."
fi
