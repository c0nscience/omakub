#!/bin/bash

# Ship default sqruff rules (core + layout) so SQL reflows the way sqlfluff
# format does. sqruff only reads a .sqruff from its working directory, so
# sql.lua points both the formatter and the language server at
# ~/.config/sqruff/.sqruff unless the project has its own. An existing
# ~/.config/sqruff/.sqruff is kept. Re-copying sql.lua is idempotent.
nvim_plugins="$HOME/.config/nvim/lua/plugins"
if [ -d "$nvim_plugins" ]; then
  cp "$OMAKUB_PATH/configs/neovim/sql.lua" "$nvim_plugins/sql.lua"
  if [ ! -f "$HOME/.config/sqruff/.sqruff" ]; then
    mkdir -p "$HOME/.config/sqruff"
    cp "$OMAKUB_PATH/configs/sqruff/.sqruff" "$HOME/.config/sqruff/.sqruff"
  fi
  echo "Updated nvim SQL config (sqruff reflows queries). Restart nvim."
fi
