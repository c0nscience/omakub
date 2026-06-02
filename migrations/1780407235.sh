#!/bin/bash

# Install the zellij-attention plugin and wire it into existing zellij + Claude Code configs
# so Claude Code state shows up in the zellij tab name.

if command -v zellij &>/dev/null; then
  mkdir -p ~/.config/zellij/plugins
  curl -L https://github.com/KiryuuLight/zellij-attention/releases/latest/download/zellij-attention.wasm \
    -o ~/.config/zellij/plugins/zellij-attention.wasm

  if [ -f ~/.config/zellij/config.kdl ] && ! grep -q "zellij-attention" ~/.config/zellij/config.kdl; then
    cat >>~/.config/zellij/config.kdl <<'KDL'

// Reflect Claude Code state in the tab name (driven by Claude Code hooks via `zellij pipe`)
load_plugins {
    "file:~/.config/zellij/plugins/zellij-attention.wasm" {
        enabled "true"
        waiting_icon "⏳"
        completed_icon "✅"
    }
}
KDL
  fi
fi

# Register Claude Code hooks to drive the plugin (only if Claude Code is configured)
if [ -f "$HOME/.claude/settings.json" ] && command -v jq &>/dev/null; then
  if ! jq -e '.hooks.Stop' "$HOME/.claude/settings.json" &>/dev/null; then
    pipe='[ -n "$ZELLIJ" ] && zellij pipe --name "zellij-attention::%s::$ZELLIJ_PANE_ID" || true'
    waiting=$(printf "$pipe" waiting)
    completed=$(printf "$pipe" completed)
    tmp=$(mktemp)
    jq --arg waiting "$waiting" --arg completed "$completed" '
      .hooks += {
        UserPromptSubmit: [{ hooks: [{ type: "command", command: $waiting }] }],
        Notification:     [{ matcher: "", hooks: [{ type: "command", command: $waiting }] }],
        Stop:             [{ hooks: [{ type: "command", command: $completed }] }]
      }' "$HOME/.claude/settings.json" >"$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
  fi
fi
