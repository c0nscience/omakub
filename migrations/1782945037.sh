#!/bin/bash

# Atuin replaces fzf's ctrl+r with sqlite-backed history that syncs across
# panes instantly (the history -a/-n sharing only refreshes at the next
# prompt). Installs atuin via mise, deploys bash-preexec + config template,
# and imports the existing ~/.bash_history once.
source $OMAKUB_PATH/install/terminal/setup-atuin.sh
