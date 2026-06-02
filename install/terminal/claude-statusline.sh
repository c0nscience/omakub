#!/bin/bash

# Claude Code statusline: model, git branch, context left, diff, duration, cost.
# Requires jq (used by the statusline script itself).
sudo apt install -y jq

mkdir -p ~/.claude
cp ~/.local/share/omakub/configs/claude/statusline.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh

# Point Claude Code at the statusline script (create settings.json if it doesn't exist)
settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || echo '{}' >"$settings"
tmp=$(mktemp)
jq --arg cmd "bash $HOME/.claude/statusline-command.sh" \
  '.statusLine = {type: "command", command: $cmd}' "$settings" >"$tmp" && mv "$tmp" "$settings"
