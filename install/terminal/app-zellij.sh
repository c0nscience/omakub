#!/bin/bash

cd /tmp
wget -O zellij.tar.gz "https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz"
tar -xf zellij.tar.gz zellij
sudo install zellij /usr/local/bin
rm zellij.tar.gz zellij
cd -

mkdir -p ~/.config/zellij/themes
[ ! -f "$HOME/.config/zellij/config.kdl" ] && cp ~/.local/share/omakub/configs/zellij.kdl ~/.config/zellij/config.kdl
cp ~/.local/share/omakub/themes/tokyo-night/zellij.kdl ~/.config/zellij/themes/tokyo-night.kdl

# notify-send (libnotify-bin) backs the desktop-notification hooks below
sudo apt install -y libnotify-bin

# Register Claude Code desktop-notification hooks (only if Claude Code is configured)
if [ -f "$HOME/.claude/settings.json" ] && command -v jq &>/dev/null; then
  if ! jq -e '.hooks.Stop' "$HOME/.claude/settings.json" &>/dev/null; then
    # At prompt-submit the Claude pane is focused, so record its tab name per pane;
    # the notify-send hooks read it back to show which tab needs you (you may have
    # switched away by the time the notification fires).
    capture='[ -n "$ZELLIJ" ] && zellij action dump-layout 2>/dev/null | grep -E "^[[:space:]]*tab name=.*focus=true" | head -1 | grep -oP "name=\"\K[^\"]+" >"${XDG_RUNTIME_DIR:-/tmp}/claude-zellij-tab-${ZELLIJ_SESSION_NAME:-x}-${ZELLIJ_PANE_ID:-x}" 2>/dev/null || true'
    tab='$(cat "${XDG_RUNTIME_DIR:-/tmp}/claude-zellij-tab-${ZELLIJ_SESSION_NAME:-x}-${ZELLIJ_PANE_ID:-x}" 2>/dev/null)'
    notify_attention='tab='"$tab"'; msg=$(jq -r ".message // \"needs your attention\""); notify-send -a "Claude Code" -u normal "Claude Code${tab:+ · $tab}" "$msg" || true'
    notify_done='tab='"$tab"'; notify-send -a "Claude Code" -u low "Claude Code${tab:+ · $tab}" "Finished responding" || true'
    tmp=$(mktemp)
    jq --arg capture "$capture" \
       --arg notify_attention "$notify_attention" --arg notify_done "$notify_done" '
      .hooks += {
        UserPromptSubmit: [{ hooks: [{ type: "command", command: $capture }] }],
        Notification:     [{ matcher: "", hooks: [{ type: "command", command: $notify_attention }] }],
        Stop:             [{ hooks: [{ type: "command", command: $notify_done }] }]
      }' "$HOME/.claude/settings.json" >"$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
  fi
fi
