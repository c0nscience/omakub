#!/bin/bash

# Add Claude Code desktop notifications (notify-send) alongside the existing
# zellij-attention hooks: pop a toast when Claude needs attention or finishes.

sudo apt install -y libnotify-bin

if [ -f "$HOME/.claude/settings.json" ] && command -v jq &>/dev/null; then
  if ! jq -e '[.. | .command? // empty] | any(test("notify-send"))' "$HOME/.claude/settings.json" &>/dev/null; then
    notify_attention='msg=$(jq -r ".message // \"needs your attention\""); notify-send -a "Claude Code" -u normal "Claude Code" "$msg" || true'
    notify_done='notify-send -a "Claude Code" -u low "Claude Code" "Finished responding" || true'
    tmp=$(mktemp)
    jq --arg attention "$notify_attention" --arg done "$notify_done" '
      .hooks //= {}
      | .hooks.Notification //= [{ matcher: "", hooks: [] }]
      | .hooks.Stop //= [{ hooks: [] }]
      | .hooks.Notification[0].hooks += [{ type: "command", command: $attention }]
      | .hooks.Stop[0].hooks += [{ type: "command", command: $done }]
    ' "$HOME/.claude/settings.json" >"$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
  fi
fi
