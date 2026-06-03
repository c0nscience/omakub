#!/bin/bash

# Global Claude Code guidelines: per-topic guideline files imported by CLAUDE.md,
# loaded into every Claude Code session. Edit the templates under
# configs/claude/, not the deployed copies in ~/.claude.

mkdir -p ~/.claude/guidelines
cp ~/.local/share/omakub/configs/claude/guidelines/*.md ~/.claude/guidelines/

# Ensure CLAUDE.md imports the guidelines. Don't clobber an existing CLAUDE.md:
# copy the template only if absent, otherwise append the imports if missing.
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
