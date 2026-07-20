#!/bin/bash

# Re-ship configs/neovim/java.lua to cut jdtls typing lag. Two changes:
#
#   1. settings.java.edit.validateAllOpenBuffersOnChanges = false
#      eclipse.jdt.ls's constructor defaults this to TRUE, so every edit
#      re-validated EVERY open Java buffer (VS Code sends false, but nvim-jdtls
#      only transmits keys we set, so unset = the server's true). Logs showed one
#      edit validating 2-4 dependent compilation units at 100-180ms each — the
#      "every keystroke triggers checks multiple times over" symptom. This scopes
#      validation to the edited buffer, matching VS Code's default.
#
#   2. jdtls flags.debounce_text_changes = 300 (up from nvim's 150ms default)
#      to throttle the didChange -> reconcile/diagnostics chain during sustained
#      typing.
#
# app-neovim.sh only copies java.lua on a fresh ~/.config/nvim, so a bare
# `git pull` leaves already-installed machines on the old file — hence this copy.
# Guarded on the deployed copy existing (nvim configured); idempotent. jdtls must
# be restarted (:LspRestart, or reopen nvim) for the settings to take effect.
java_config="$HOME/.config/nvim/lua/plugins/java.lua"
if [ -f "$java_config" ]; then
  cp "$OMAKUB_PATH/configs/neovim/java.lua" "$java_config"
  echo "Updated nvim java.lua (jdtls responsiveness). Run :LspRestart in any open Java buffer."
fi
