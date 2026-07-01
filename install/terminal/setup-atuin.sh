#!/bin/bash

# Atuin: SQLite-backed shell history — records every command at execution
# time, so panes share history instantly; fzf-style ctrl+r search TUI.
# Wired into the shell in defaults/bash/init.
mise use --global atuin@latest

mkdir -p "$HOME/.config/atuin"

# bash-preexec provides the preexec hook atuin needs on bash (pinned release)
if [ ! -f "$HOME/.config/atuin/bash-preexec.sh" ]; then
  curl -L --proto '=https' --tlsv1.2 -sSf \
    -o "$HOME/.config/atuin/bash-preexec.sh" \
    https://raw.githubusercontent.com/rcaloras/bash-preexec/0.6.0/bash-preexec.sh
fi

if [ ! -f "$HOME/.config/atuin/config.toml" ]; then
  cp "$OMAKUB_PATH/configs/atuin/config.toml" "$HOME/.config/atuin/config.toml"
fi

# One-time import of the existing bash history; menu re-runs keep the db
if [ ! -f "$HOME/.local/share/atuin/history.db" ] && [ -s "$HOME/.bash_history" ]; then
  mise exec -- atuin import auto
fi
