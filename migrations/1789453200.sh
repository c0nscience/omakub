#!/bin/bash

# Re-ship the consolidated jdtls config. configs/neovim/java.lua was rewritten
# into four blocks (JVM args, settings, capabilities, client-side cuts): dead
# settings dropped, the vscode-java parity keys added, the two request-level
# hacks moved out to plugin/jdtls-experimental.lua, and file watching gated on
# inotify-tools. bufferline-coalesce-refresh.lua joins omakub alongside it.
# perflog.lua is deliberately NOT re-shipped: the repo copy now carries this
# box's always-on QUEUE/SPIKE probes, which other machines never opted into;
# fresh installs get it from app-neovim.sh.
# app-neovim.sh copies these only on a fresh ~/.config/nvim, so a bare
# `git pull` would leave the deployed copies behind. The plugin files ship
# wherever ~/.config/nvim exists (same guard as 1787148491); java.lua only
# replaces a deployed copy. Re-copying is idempotent.
nvim_config="$HOME/.config/nvim"
if [ -d "$nvim_config" ]; then
  if [ -f "$nvim_config/lua/plugins/java.lua" ]; then
    cp "$OMAKUB_PATH/configs/neovim/java.lua" "$nvim_config/lua/plugins/java.lua"
  fi
  mkdir -p "$nvim_config/plugin"
  for f in jdtls-experimental.lua bufferline-coalesce-refresh.lua; do
    cp "$OMAKUB_PATH/configs/neovim/$f" "$nvim_config/plugin/$f"
  done
  # Superseded live-only patch of nvim-jdtls' test-result reader: correct, but
  # negligible at real test-output volumes and one more thing to carry.
  rm -f "$nvim_config/plugin/jdtls-test-stream.lua"
  echo "Updated nvim jdtls config (java.lua, plugin/jdtls-experimental.lua, plugin/bufferline-coalesce-refresh.lua). Restart nvim in Java projects."
fi
