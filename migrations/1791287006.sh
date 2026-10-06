#!/bin/bash

# Ship the sqruff SQL setup. LazyVim's sql extra formats with sqlfluff, which
# conform only runs under a .sqlfluff/pyproject.toml root, so SQL had no
# formatter anywhere else. app-neovim.sh copies configs only on a fresh
# ~/.config/nvim. Re-copying is idempotent.
nvim_plugins="$HOME/.config/nvim/lua/plugins"
if [ -d "$nvim_plugins" ]; then
  cp "$OMAKUB_PATH/configs/neovim/sql.lua" "$nvim_plugins/sql.lua"
  echo "Updated nvim SQL config (sqruff formats and lints). Restart nvim."
fi
