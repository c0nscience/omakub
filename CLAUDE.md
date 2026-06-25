# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Omakub turns a fresh Ubuntu 24.04+ (x86_64) installation into a configured web-development system. This is a personal fork (`c0nscience/omakub`) of the upstream Basecamp project. It is **not an application** — there is no build, no test suite, and no compiled artifact. The entire codebase is Bash scripts plus config templates that install software and write dotfiles to the user's machine.

Because scripts mutate the live system (`apt install`, `sudo`, `gsettings`, copying into `~/.config`), do **not** run installers to "test" a change in this environment. Reason about correctness by reading the scripts; validate at most with `bash -n script.sh` (syntax check) or `shellcheck`.

The repo is expected to live at `~/.local/share/omakub`, which is the value of `$OMAKUB_PATH` (set in the user's bash config). Scripts reference each other through `$OMAKUB_PATH` or the literal `~/.local/share/omakub` path.

## Entry points

- **`boot.sh`** — the one-liner pitch target. Installs git, clones the repo into `~/.local/share/omakub`, then sources `install.sh`.
- **`install.sh`** — full first-time install. Checks OS version, gathers choices (`first-run-choices.sh`, `identification.sh`), then sources `install/terminal.sh` always, and `install/desktop.sh` only under GNOME.
- **`bin/omakub`** — the post-install TUI command (on `PATH`). Sources `header.sh` then `menu.sh`, which presents Theme / Font / Update / Install / Uninstall / Manual. Each menu item sources the matching `bin/omakub-sub/<name>.sh`, which does its work and then re-sources `bin/omakub` to return to the menu.

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

`bin/omakub-sub/migrate.sh` (triggered by Update → Omakub) records the previous git timestamp, runs `git pull`, then sources every `migrations/*.sh` whose **Unix-timestamp filename is newer than the last pull**. Files are named `<unix-epoch>.sh`. To ship a one-time change to already-installed machines (a settings tweak, a moved file), add a migration named with the current epoch (`date +%s`). Migrations are sourced, so the same "no `exit`, share the environment" rules apply.

## Agent Visual Companion (AVC)

Publish your research, mockups, diagrams, and other artifacts to the Agent Visual
Companion (https://agent.hrzg.org) so they can be browsed and reviewed.

**Enroll once** — only on a fresh machine with no agent anywhere. An agent already
exists (in the home `~/.avc`); because avc is folder-scoped (see below), `avc whoami`
failing *inside a project dir* just means there's no `.avc` there — **not** that
enrollment is needed. Re-running `avc enroll` mints a *new* agent each time, so do it
at most once:

```bash
curl -fsSL https://agent.hrzg.org/cli/avc -o ~/.local/bin/avc && chmod +x ~/.local/bin/avc
export AVC_ENROLL_TOKEN_REF="op://Deploy/AVC Tokens/Enrollment/ENROLL_TOKEN"
avc enroll
avc set-identity --description "Claude Code agent for omakub — <what you do>"
```

`avc enroll` stores your API token in 1Password and writes a `.avc` config file
(`AVC_HANDLE`, `AVC_TOKEN_REF`, `AVC_BASE_URL` — a reference, not the secret). avc
reads `.avc` **from the current directory only** (or `$AVC_CONFIG_FILE` if set) —
folder-scoped on purpose, with **no walk-up** to parent dirs, so an ancestor's `.avc`
can't leak into a project that lacks its own. **Never `export AVC_TOKEN_REF`** (or
paste it into CLAUDE.md): a stray export overrides `.avc` and can silently swap your
agent identity. The one-time `avc enroll` still needs `AVC_ENROLL_TOKEN_REF` from the
environment (already set in `~/.claude/settings.json`) — that bootstrap token is
intentionally not kept in `.avc`.

Because discovery is folder-scoped, the home `~/.avc` does **not** cover omakub (it
applies only when the working directory *is* `$HOME`). To publish from this repo,
point avc at it explicitly — `AVC_CONFIG_FILE="$HOME/.avc" avc push …` — or add a
project-local `.avc` here.

**From now on, use `avc`** to publish work:
`avc push <slug> <file...> --headline "…" --description "…"`. Run `avc help` for all commands.

### Wait for the human's review

After pushing, wait for the verdict instead of moving on blind:
- `avc push <slug> <file...> --wait` — publish, then block until the human approves or requests changes.
- `avc feedback --watch` — stream every verdict (approvals + change-requests) as it lands.

### Pushing visual designs

AVC renders pushed HTML in a sandboxed, **script-disabled** iframe, so:
- **Inline all CSS** in a `<style>` block. Don't style via JavaScript — the Tailwind Play CDN (`<script src="https://cdn.tailwindcss.com">`) and other runtime-JS frameworks will **not** run, so the page renders as raw unstyled text.
- **No sibling/relative files** (`<link href="styles.css">`, `<img src="logo.png">`) — the preview has no base URL. Inline CSS; embed images as `data:` URIs.
- **Always also push a PNG screenshot** of the design — images render reliably and are the visual of record.

### Feedback to the AVC maintainer

Have feedback on AVC itself — an `avc` CLI papercut, a bug, friction, or a feature
request? Drop a short markdown note in the maintainer's watched inbox (it is read
and acted on automatically):

    /home/bhe/Documents/projects/agent-visual-companion/docs/feedback/

Name it `YYYY-MM-DD-<your-handle>.md` (your handle from `avc whoami`). Say what you
were doing, what you expected, and what actually happened.
