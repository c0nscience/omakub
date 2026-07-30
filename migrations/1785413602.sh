#!/bin/bash

# Two cleanups now that opencode-sec replaced claude-sec and opencode is an
# omakub-managed install.

# 1. Retire ~/.config/op/claude-sec.env. The claude-sec function is gone, so the
# file is an orphaned secret reference (the OpenRouter key itself lives on in
# opencode-sec.env). Only removed when it still contains nothing but the
# ANTHROPIC_AUTH_TOKEN line omakub shipped - if anything else was added locally,
# it is left alone and reported, since that is a hand-edited file at that point.
claude_sec_env="$HOME/.config/op/claude-sec.env"
if [ -f "$claude_sec_env" ]; then
	other_vars=$(grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$claude_sec_env" | grep -cv '^[[:space:]]*ANTHROPIC_AUTH_TOKEN=')
	if [ "$other_vars" -eq 0 ]; then
		rm -f "$claude_sec_env"
		echo "Removed $claude_sec_env (claude-sec was replaced by opencode-sec)."
	else
		echo "Kept $claude_sec_env: it declares variables beyond ANTHROPIC_AUTH_TOKEN. Remove it by hand once nothing needs them."
	fi
fi

# 2. Converge a hand-installed opencode onto the layout the omakub installer
# uses. opencode's upstream installer appends a PATH export to ~/.bashrc; omakub
# instead links the binary into ~/.local/bin, which defaults/bash/shell already
# puts on PATH. Link first, then drop the ~/.bashrc block - and only if the link
# exists, so this can never take opencode off PATH. The sed deletes the comment
# and its export as a pair, leaving an unrelated `# opencode` comment untouched.
if [ -x "$HOME/.opencode/bin/opencode" ]; then
	mkdir -p "$HOME/.local/bin"
	ln -sf "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"

	if [ -L "$HOME/.local/bin/opencode" ] && [ -f "$HOME/.bashrc" ] &&
		grep -qE '^[[:space:]]*export PATH=.*\.opencode/bin' "$HOME/.bashrc"; then
		sed -i '/^# opencode$/{N;/\n[[:space:]]*export PATH=.*\.opencode\/bin/d}' "$HOME/.bashrc"
		echo "Linked opencode into ~/.local/bin and dropped its PATH block from ~/.bashrc."
	fi
fi
