#!/bin/bash

# Ship lsp-coalesce-highlight.lua to already-installed machines. Caps
# outstanding textDocument/documentHighlight requests at one per buffer, so a
# slow/busy LSP server can't pile them up and blow up nvim's own memory.
if [ -d "$HOME/.config/nvim" ]; then
  mkdir -p ~/.config/nvim/plugin
  cp $OMAKUB_PATH/configs/neovim/lsp-coalesce-highlight.lua ~/.config/nvim/plugin/
fi
