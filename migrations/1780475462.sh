#!/bin/bash

# Add Claude Code desktop notifications (notify-send) alongside the existing
# zellij-attention hooks: pop a toast when Claude needs attention or finishes,
# titled with the zellij tab the prompt was started in (captured at submit time,
# since you've usually switched away by the time the notification fires).

sudo apt install -y libnotify-bin

if [ -f "$HOME/.claude/settings.json" ] && command -v jq &>/dev/null; then
  # Skip if already tab-aware (the capture marker is only present once installed).
  if ! jq -e '[.. | .command? // empty] | any(test("claude-zellij-tab"))' "$HOME/.claude/settings.json" &>/dev/null; then
    capture='[ -n "$ZELLIJ" ] && zellij action dump-layout 2>/dev/null | grep -E "^[[:space:]]*tab name=.*focus=true" | head -1 | grep -oP "name=\"\K[^\"]+" >"${XDG_RUNTIME_DIR:-/tmp}/claude-zellij-tab-${ZELLIJ_SESSION_NAME:-x}-${ZELLIJ_PANE_ID:-x}" 2>/dev/null || true'
    tab='$(cat "${XDG_RUNTIME_DIR:-/tmp}/claude-zellij-tab-${ZELLIJ_SESSION_NAME:-x}-${ZELLIJ_PANE_ID:-x}" 2>/dev/null)'
    attention='tab='"$tab"'; msg=$(jq -r ".message // \"needs your attention\""); notify-send -a "Claude Code" -u normal "Claude Code${tab:+ · $tab}" "$msg" || true'
    done_cmd='tab='"$tab"'; notify-send -a "Claude Code" -u low "Claude Code${tab:+ · $tab}" "Finished responding" || true'
    tmp=$(mktemp)
    jq --arg capture "$capture" --arg attention "$attention" --arg done "$done_cmd" '
      .hooks //= {}
      | .hooks.UserPromptSubmit //= [{ hooks: [] }]
      | .hooks.Notification //= [{ matcher: "", hooks: [] }]
      | .hooks.Stop //= [{ hooks: [] }]
      | .hooks.UserPromptSubmit[0].hooks += [{ type: "command", command: $capture }]
      | .hooks.Notification[0].hooks |= (if any(.[].command // ""; test("notify-send"))
          then map(if (.command // "" | test("notify-send")) then .command = $attention else . end)
          else . + [{ type: "command", command: $attention }] end)
      | .hooks.Stop[0].hooks |= (if any(.[].command // ""; test("notify-send"))
          then map(if (.command // "" | test("notify-send")) then .command = $done else . end)
          else . + [{ type: "command", command: $done }] end)
    ' "$HOME/.claude/settings.json" >"$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
  fi
fi
