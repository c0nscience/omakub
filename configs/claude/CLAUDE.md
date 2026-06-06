# CLAUDE.md

This file is loaded into **every** Claude Code session. The first section holds
global guidelines that apply to all projects; the rest documents the `~/.claude`
directory itself (only relevant when actually working in here).

## Global guidelines (apply to every project)

@~/.claude/guidelines/workflow.md
@~/.claude/guidelines/code.md
@~/.claude/guidelines/git.md
@~/.claude/guidelines/testing.md
@~/.claude/guidelines/documentation.md
@~/.claude/guidelines/security.md
@~/.claude/guidelines/debugging.md
@~/.claude/guidelines/communication.md

## What this directory is

This is `~/.claude` — Claude Code's **user-level config and state home**, not a software
project. There is no application source code, build system, or test suite here. Most
subdirectories are runtime state managed by Claude Code itself; do not hand-edit them.

The only human-authored, meaningful-to-edit files are:

- `settings.json` — user settings (see below).
- `statusline-command.sh` — custom status line renderer.

## settings.json

Active configuration:

- `model: opus`, `effortLevel: high` — defaults for new sessions.
- `statusLine` — runs `statusline-command.sh` (below).
- `enabledPlugins` — `rust-analyzer-lsp` and `pyright-lsp` from `claude-plugins-official`,
  giving Rust and Python language-server support.

A user-level `settings.local.json` (gitignored, machine-specific overrides) may also exist
or be created here. Permissions, env vars, and hooks also live in these settings files —
prefer the `update-config` skill over editing them blind.

## statusline-command.sh

Reads the session JSON from stdin and prints, pipe-separated: model name + thinking level,
output style (when non-default), git branch (when in a repo), context-token usage as
`used/total` (e.g. `45k/200k`), lines added/removed, session duration, total cost, and the
current directory name. Requires `jq` and `awk`. If you change the displayed fields, keep it
a single fast `printf` — the status line runs on every render.

## State directories (do not hand-edit)

`projects/`, `sessions/`, `session-env/`, `tasks/`, `file-history/`, `shell-snapshots/`,
`backups/`, `debug/`, `plans/`, `cache/`, `statsig/`, `plugins/`, and the `.*.json` files
are all Claude Code runtime state. Treat them as read-only unless explicitly debugging.

## Memory

Persistent file-based memory lives under
`projects/-home-bhe--claude/memory/` with an `MEMORY.md` index. Follow the memory
conventions from the system prompt when writing facts there.
