#!/bin/bash

# Refresh the Claude Code statusline script (now shows the effort level in the
# model bracket). Updates machines that already have the statusline deployed.

if [ -f "$HOME/.claude/statusline-command.sh" ]; then
  cp ~/.local/share/omakub/configs/claude/statusline.sh ~/.claude/statusline-command.sh
  chmod +x ~/.claude/statusline-command.sh
fi
