#!/bin/bash

# Re-ship statusline.sh to follow the AVC -> stet rename. The agent handle that
# shows as "🤖 <name>" used to be read from a per-project .avc file (AVC_HANDLE=);
# stet now keeps it in .stet (STET_HANDLE=), so the old lookup finds nothing and
# the segment silently drops. A bare `git pull` is not enough on its own here:
# claude-statusline.sh copies the script to ~/.claude/statusline-command.sh at
# install time, and that installer only re-runs from the Install menu, so the
# deployed copy would keep reading .avc.
#
# Deliberately a plain copy rather than `source claude-statusline.sh` — the
# installer opens with `sudo apt install -y jq`, which would prompt for a
# password on an otherwise passwordless update just to no-op on a package that
# is already there. settings.json already points at this path, so refreshing the
# file is the whole job.
#
# Guarded on the deployed copy existing: if it does, the installer has run and
# jq is present. Idempotent — re-copying an already-updated script changes nothing.
statusline="$HOME/.claude/statusline-command.sh"
if [ -f "$statusline" ]; then
  cp "$OMAKUB_PATH/configs/claude/statusline.sh" "$statusline"
  chmod +x "$statusline"
  echo "Updated Claude Code status line (agent handle now reads .stet)."
fi
