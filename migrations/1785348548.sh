#!/bin/bash

# Ship ~/.config/op/claude-sec.env for the new claude-sec wrapper (GLM 5.2 via
# OpenRouter). The token gets its OWN env file rather than a line in the shared
# ~/.config/op/.env: that file is injected into normal `claude` sessions too,
# and an ANTHROPIC_AUTH_TOKEN there would silently override their subscription
# auth and reroute every session to OpenRouter. Only the 1Password secret
# reference is written — `op run` resolves it at launch, so the real key never
# lands on disk. Guarded on the file not existing: a present file may carry
# local edits (different vault, rotated item) and is left untouched. Idempotent.
env_file="$HOME/.config/op/claude-sec.env"
if [ ! -f "$env_file" ]; then
  mkdir -p "$(dirname "$env_file")"
  cat >"$env_file" <<'EOF'
# 1Password secret reference for the claude-sec wrapper (GLM 5.2 via
# OpenRouter's Anthropic-compatible endpoint). Resolved at launch by `op run`
# in the claude-sec function — the real key is never stored on disk. Kept
# separate from .env so normal `claude` sessions never inherit
# ANTHROPIC_AUTH_TOKEN, which would override their subscription auth.
ANTHROPIC_AUTH_TOKEN="op://Private/OpenRouter/workspaces/default api key"
EOF
  echo "Created $env_file (claude-sec OpenRouter token reference)."
fi
