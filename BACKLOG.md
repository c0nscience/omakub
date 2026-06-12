# Backlog

## Replace alacritty + zellij with kitty

**Status:** adopted & implemented in omakub on 2026-06-12 — kitty is the
omakub-managed terminal; alacritty + zellij removed from the repo. Migration
`migrations/1781289040.sh` switches existing installs (carries theme/font over,
rewrites the launcher apps, swaps defaults, retires zellij + alacritty).

### Why (kept for the record)

- zellij 0.43.1 became unstable/slow: both servers idle at ~8% CPU for days, session
  manager tracked 79+90 "panes" while only 10+21 live shells existed (phantom pane
  state bloat). Session serialization already disabled earlier for the same reason.
- Original trigger: yazi image previews need a graphics protocol. Alacritty has none
  and won't add one (verified through 0.17.0, Apr 2026); kitty's protocol is native.
- kitty 0.47 covers the zellij features actually used (modal keybindings via keyboard
  modes, splits, tabs, per-pane cwd titles) without a multiplexer process.

### How it landed

- `install/desktop/app-kitty.sh` — official installer into `~/.local/kitty.app`
  (apt kitty is 0.32, needs ≥0.47 for `window_title_bar_*`), config templates
  from `configs/kitty/` (kitty.conf + theme/font/font-size includes, pane/btop
  confs, `tab_bar.py`, `focus_or_tab.py`), `set-kitty-default.sh` for
  update-alternatives + nautilus menu.
- `themes/*/kitty.conf` for all 9 themes; `tab_bar.py` mode-cell colors now read
  the live theme palette (everforest fallback).
- Trial config in `~/.config/kitty` gets overwritten by the omakub-managed
  copies when the migration runs — template parses identical to the trial
  (verified option-for-option with kitty's config loader).

Known deltas vs zellij (accepted): no floating panes, no detach/sessions, full-page
instead of half-page scroll, scrollback search via pager, per-axis resize, no per-focus
border width (doubled globally to 1pt instead).

### Follow-ups

- Only everforest was visually trialed; the other 8 theme `kitty.conf` files are
  derived from their alacritty/upstream palettes — eyeball each on first switch.
- Claude Code notify-send hook registration was dropped from omakub entirely
  (went away with `app-zellij.sh`); hooks already registered in
  `~/.claude/settings.json` on existing machines are untouched.

### Rollback (now = uninstall)

`uninstall/app-kitty.sh` removes kitty.app, configs, symlinks, desktop entry, and
the nautilus extension. Reinstating alacritty+zellij means reverting the omakub
commit ("replace alacritty and zellij with kitty") and re-running the installers.

### Alternatives evaluated and rejected

- **ghostty** (benched earlier): also has kitty graphics + native splits and would fit
  omakub's GNOME/libadwaita look, but keybinds are one-shot trigger sequences only —
  no sticky modes (verified in docs, 1.3.x) and no scripting surface, so the zellij
  modal scheme and focus-or-tab spillover can't be replicated.
- **Upgrading alacritty** (0.13.2→0.17.0): maintenance-grade changes only, no graphics
  protocol — doesn't address the trigger.
- **zellij + sixel terminal (foot/wezterm)**: keeps navigation untouched but keeps the
  unstable zellij server; not pursued.
