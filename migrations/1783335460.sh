#!/bin/bash

# Strip the Claude Code notification hooks omakub used to register in
# ~/.claude/settings.json. Three variants shipped over time and all are now dead
# (zellij is gone; the notify-send desktop toasts were retired in commit e35c0d0
# but left in place on already-configured machines). They are identified by a
# marker in their command:
#   - "zellij-attention" — UserPromptSubmit/Notification/Stop hooks that drove
#     the zellij-attention tab plugin (via `zellij pipe`)
#   - "notify-send"      — Notification/Stop desktop toasts
#   - "claude-zellij-tab" — the UserPromptSubmit capture helper for the toasts
# Remove only hook entries whose command matches those markers, leave any hooks
# the user added, and prune the matcher-groups / event keys / .hooks object that
# become empty as a result.

settings="$HOME/.claude/settings.json"
if [ -f "$settings" ] && command -v jq &>/dev/null &&
  jq -e '.hooks | type == "object"' "$settings" &>/dev/null; then
  tmp=$(mktemp)
  jq --arg re 'notify-send|claude-zellij-tab|zellij-attention' '
    .hooks |= (
      with_entries(
        .value |= (
          if type == "array" then
            map(if (.hooks | type) == "array"
                then .hooks |= map(select((.command // "") | test($re) | not))
                else . end)
            | map(select((.hooks | type) != "array" or (.hooks | length) > 0))
          else . end
        )
      )
      | with_entries(select((.value | type) != "array" or (.value | length) > 0))
    )
    | if (.hooks | length) == 0 then del(.hooks) else . end
  ' "$settings" >"$tmp" && mv "$tmp" "$settings"
fi
