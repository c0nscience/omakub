#!/bin/bash

# Ship ~/.config/op/opencode-sec.env for the new opencode-sec wrapper. Same
# OpenRouter key as claude-sec, under the variable name opencode expects:
# claude-sec.env exports it as ANTHROPIC_AUTH_TOKEN because Claude Code reads
# the credential from there, while the opencode profile resolves it as
# OPENROUTER_API_KEY via {env:OPENROUTER_API_KEY}. Reusing claude-sec.env would
# mean naming an OpenRouter key after Anthropic in an opencode session and
# would tie the opencode path to a file that exists for the Claude Code one, so
# each wrapper gets its own file. Neither is added to the shared
# ~/.config/op/.env, which is injected into normal `claude` sessions too.
# Only the 1Password secret reference is written - `op run` resolves it at
# launch, so the real key never lands on disk. Guarded on the file not
# existing: a present file may carry local edits (different vault, rotated
# item) and is left untouched. Idempotent.
env_file="$HOME/.config/op/opencode-sec.env"
if [ ! -f "$env_file" ]; then
  mkdir -p "$(dirname "$env_file")"
  cat >"$env_file" <<'EOF'
# 1Password secret reference for the opencode-sec wrapper (GLM 5.2 via
# OpenRouter). Resolved at launch by `op run` in the opencode-sec function - the
# real key is never stored on disk, and never enters opencode's auth.json.
# Kept separate from .env so normal `claude` sessions never inherit it.
OPENROUTER_API_KEY="op://Private/OpenRouter/workspaces/default api key"
EOF
  echo "Created $env_file (opencode-sec OpenRouter key reference)."
fi
