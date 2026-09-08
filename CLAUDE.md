# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Omakub turns a fresh Ubuntu 24.04+ (x86_64) installation into a configured web-development system. This is a personal fork (`c0nscience/omakub`) of the upstream Basecamp project. It is **not an application** — there is no build, no test suite, and no compiled artifact. The entire codebase is Bash scripts plus config templates that install software and write dotfiles to the user's machine.

Because scripts mutate the live system (`apt install`, `sudo`, `gsettings`, copying into `~/.config`), do **not** run installers to "test" a change in this environment. Reason about correctness by reading the scripts; validate at most with `bash -n script.sh` (syntax check) or `shellcheck`.

The repo is expected to live at `~/.local/share/omakub`, which is the value of `$OMAKUB_PATH` (set in the user's bash config). Scripts reference each other through `$OMAKUB_PATH` or the literal `~/.local/share/omakub` path.

## Divergence from upstream

This fork left upstream (`basecamp/omakub`, now `omacom/omakub`) at commit `7311ef2` (2024-06-06) and has not merged from it since. Both sides then rewrote the same directories: 267 of the 317 files that changed were touched on **both** sides, and a sync attempt conflicts in ~70 of them.

**Do not attempt a wholesale upstream merge.** Neither `-X ours` nor `-X theirs` yields a working tree — the conflicts sit exactly where this fork made deliberate changes that upstream also touched, so resolving them means re-applying every customization below by hand. Pull individual upstream changes deliberately instead.

The divergences below are intentional. When upstream code or an outdated doc disagrees with the tree, this is usually why:

- **The terminal emulator is Kitty, not Alacritty + Zellij.** The largest divergence, and the one touching the most files: `themes/*/kitty.conf` (upstream ships `alacritty.toml` + `zellij.kdl`), `configs/kitty/`, `applications/Neovim.sh` (launches nvim inside kitty), and `bin/omakub-sub/theme.sh` (copies `kitty.conf`, reloads via `pkill -USR1 kitty`). No Alacritty or Zellij config remains.
- **Migrations run from a state ledger, not from git commit dates** — see the Migrations section below. Upstream still compares filename epochs against the pre-pull HEAD date.
- **mise installs via `extrepo`** (`install/terminal/mise.sh`), not upstream's manual GPG-key-and-apt-source method.
- **Java installs several Zulu versions plus Maven** and defaults to `zulu-17` (`install/terminal/select-dev-language.sh`); upstream does `mise use --global java@latest`.
- **Different first-run defaults** (`install/first-run-choices.sh`): Go, Node.js, Python, Rust and Java with PostgreSQL, where upstream is Rails-centric (Ruby on Rails + Node.js, MySQL/Redis).
- **A trimmed apt list** (`install/terminal/apps-terminal.sh`): fzf, ripgrep, bat, eza, zoxide and fd-find are not installed from apt here; plocate, apache2-utils, tldr and dos2unix are added.
- **Shell aliases and functions are substantially rewritten** (`defaults/bash/aliases`, `defaults/bash/functions`) — eza/ripgrep/xh in place of the coreutils defaults, plus kubectl, git, VPN and Claude Code wrapper helpers.
- **`boot.sh` clones this fork**, and the `OMAKUB_REF` checkout logic is commented out. Deliberate; leave it.
- **Extra menu entries**: `Indexing` in the main menu (`bin/omakub-sub/indexing.sh`), plus Opencode and Kitty in the Update menu (`bin/omakub-sub/update.sh`).

About 99 files exist only in this fork with no upstream counterpart — `CLAUDE.md`, `BACKLOG.md`, `configs/claude/`, `configs/kitty/`, `configs/atuin/`, `applications/9to5.sh`, `applications/Yazi.sh` among them. These never conflict on a sync.

## Entry points

- **`boot.sh`** — the one-liner pitch target. Installs git, clones the repo into `~/.local/share/omakub`, then sources `install.sh`.
- **`install.sh`** — full first-time install. Checks OS version, gathers choices (`first-run-choices.sh`, `identification.sh`), then sources `install/terminal.sh` always, and `install/desktop.sh` only under GNOME.
- **`bin/omakub`** — the post-install TUI command (on `PATH`). Sources `header.sh` then `menu.sh`, which presents Theme / Font / Update / Install / Uninstall / Indexing / Manual. Each menu item sources the matching `bin/omakub-sub/<name>.sh`, which does its work and then re-sources `bin/omakub` to return to the menu.

## How installers are discovered and run

`install/terminal.sh` and `install/desktop.sh` glob-source **every** `*.sh` in their directory in alphabetical order:

```bash
for installer in ~/.local/share/omakub/install/terminal/*.sh; do source $installer; done
```

This means:

- **File order matters.** Naming controls sequencing — e.g. `a-shell.sh` / `a-flatpak.sh` run first, `app-*.sh` next, `set-*.sh` later. Add a prefix if a new script must run before/after others.
- **A script in `install/terminal/` or `install/desktop/` runs unconditionally** during install. To make an app optional, put it in the `optional/` subdirectory — those are **not** globbed, and are only invoked on demand.
- Scripts are **sourced, not executed**, so they share one shell and one environment. Avoid `exit`; a non-zero command aborts the whole install (`install.sh` runs under `set -e` with an error trap).

`optional/` apps reach the user three ways: the `bin/omakub-sub/install.sh` menu (which maps a label to a file path via a `case` block), the `select-*.sh` pickers, or `OMAKUB_FIRST_RUN_*` env vars exported by `first-run-choices.sh`.

## Conventions for installer scripts

- **gum drives all interaction.** `gum choose`, `gum confirm`, `gum file`, `gum spin`. `app-gum.sh` is installed before anything else so it is always available.
- **Idempotency by guard, not by design.** Many scripts wrap config setup in `if [ ! -d "$HOME/.config/..." ]` so re-running won't clobber user edits (see `install/terminal/app-neovim.sh`). Match this when a script can be re-run from the menu.
- **First-run vs. menu re-run.** Pickers check `if [[ -v OMAKUB_FIRST_RUN_LANGUAGES ]]` to use the pre-selected value during install, otherwise prompt via gum (see `select-dev-language.sh`). Follow this pattern for anything offered both at install time and later.
- **mise** (`install/terminal/mise.sh`) is the version manager for languages/tools; prefer `mise use --global <tool>@<ver>` over manual installs where a plugin exists.

## Themes

`THEME_NAMES` in `bin/omakub-sub/theme.sh` lists the selectable themes; each must have a matching directory under `themes/` (lowercased, spaces → hyphens, e.g. "Tokyo Night" → `tokyo-night/`). A theme directory contains one file per themed app:

`kitty.conf`, `neovim.lua`, `btop.theme` (optional), `background.jpg`, plus `gnome.sh`, `tophat.sh`, `vscode.sh` (each a script that applies that app's theming).

`theme.sh` copies these into the right `~/.config` locations and `sed`-patches config files to point at the new theme. **Adding a theme means adding its name to `THEME_NAMES` and creating a complete directory** — a missing file (other than the optional `btop.theme`) will break theme switching.

## Other directories

- **`configs/`** — static config templates (neovim Lua files, kitty, ssh, typora, etc.) copied verbatim into `~/.config` by installers. Edit the template here, not the deployed copy.
- **`defaults/bash/`** — shell config sourced from the user's `~/.bashrc`: `aliases`, `functions`, `prompt`, `shell`, `init` (mise/zoxide/fzf activation), `inputrc`. `rc` is the file that chains them.
- **`applications/`** — `.desktop` launcher generators (e.g. `Neovim.sh` makes nvim launch inside Kitty) and icons.
- **`uninstall/`** — mirror of installers; the Uninstall menu lets the user pick one via `gum file`.

## Commit conventions

Commit messages are short, lowercase, imperative-mood summaries — no Conventional Commits prefix, no scope, no trailing period. They name the change directly:

```
add csvview
fix java
update lazyvim.json
improve jdtls performance
multi select fzf config
```

Common leading verbs: `add`, `fix`, `update`, `change`, `remove`, `improve`, `bump`. Keep it to a single line; the history is overwhelmingly one-liners. Commit only when the user asks.

## Migrations

`bin/omakub-sub/migrate.sh` (triggered by Update → Omakub) runs `git pull`, then sources every `migrations/*.sh` **not already recorded in the state ledger** at `${XDG_STATE_HOME:-~/.local/state}/omakub/applied-migrations`. A migration is appended to the ledger as soon as it runs, so it runs exactly once per machine no matter how HEAD moved. Files are still named `<unix-epoch>.sh`. To ship a one-time change to already-installed machines (a settings tweak, a moved file), add a migration named with the current epoch (`date +%s`). Migrations are sourced, so the same "no `exit`, share the environment" rules apply — and they should be written to be idempotent.

The ledger replaced upstream's scheme of comparing each filename epoch against the pre-pull commit date, which permanently skipped a migration whenever HEAD advanced out of band (a bare `git pull`, or any commit landing after that migration's epoch). On a machine with no ledger yet, one is seeded from a **fixed** baseline epoch so pre-ledger migrations are not re-run; read the comments in `migrate.sh` before touching that constant, as deriving it from HEAD reopens the very bug the rewrite closed.
