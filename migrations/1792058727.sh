#!/bin/bash

nvim_plugins="$HOME/.config/nvim/lua/plugins"
if [ -d "$nvim_plugins" ]; then
  cp "$OMAKUB_PATH/configs/neovim/dotnet.lua" "$nvim_plugins/dotnet.lua"
  echo "Switched nvim C# from OmniSharp to the Roslyn language server. Restart nvim."
fi
