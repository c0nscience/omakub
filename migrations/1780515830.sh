#!/bin/bash

# Install the global Claude Code guideline files and wire them into CLAUDE.md
# (per-topic rules imported into every Claude Code session).

mkdir -p ~/.claude/guidelines
cp ~/.local/share/omakub/configs/claude/guidelines/*.md ~/.claude/guidelines/

claudemd="$HOME/.claude/CLAUDE.md"
if [ ! -f "$claudemd" ]; then
  cp ~/.local/share/omakub/configs/claude/CLAUDE.md "$claudemd"
elif ! grep -q "@~/.claude/guidelines/" "$claudemd"; then
  {
    echo ""
    echo "## Global guidelines (apply to every project)"
    echo ""
    for f in ~/.local/share/omakub/configs/claude/guidelines/*.md; do
      echo "@~/.claude/guidelines/$(basename "$f")"
    done
  } >>"$claudemd"
fi
