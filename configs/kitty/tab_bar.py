"""Custom kitty tab bar replicating zellij's compact bar:
keyboard-mode cell on the left, then powerline tabs. The focused pane's cwd
is shown in the per-pane title bars (window_title_bar_* in kitty.conf), not
here — mirroring zellij's frame titles.

Wired up via `tab_bar_style custom` in kitty.conf. kitty refreshes the bar on
keyboard-mode changes (Mappings carries a refresh_active_tab_bar callback), so
the mode cell updates instantly. Everything risky is guarded: if internals
drift, the bar degrades to plain tabs; input handling is never affected.
"""

from kitty.fast_data_types import Screen, get_boss, get_options
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_tab_with_powerline,
)
from kitty.utils import color_as_int

#: everforest fallback, used only if reading the live theme fails
FALLBACK_FG = 0xD3C6AA
FALLBACK_BG = 0x2D353B
FALLBACK_MODES = {
    '': ('LOCKED', FALLBACK_FG, 0x475258),
    'nav': ('NORMAL', FALLBACK_BG, 0xA7C080),
    'pane': ('PANE', FALLBACK_BG, 0x7FBBB3),
    'tab': ('TAB', FALLBACK_BG, 0xDBBC7F),
    'resize': ('RESIZE', FALLBACK_BG, 0xE67E80),
    'scroll': ('SCROLL', FALLBACK_BG, 0x83C092),
    'move': ('MOVE', FALLBACK_BG, 0xD699B6),
}


def _mode_styles() -> dict:
    """mode name -> (label, fg, bg), built from the active theme's ANSI
    palette so the cell follows omakub theme switches (mirrors zellij's
    mode colors: green=normal, blue=pane, yellow=tab, red=resize, ...)."""
    try:
        opts = get_options()
        fg = color_as_int(opts.foreground)
        bg = color_as_int(opts.background)

        def c(i: int) -> int:
            return color_as_int(getattr(opts, f'color{i}'))

        return {
            '': ('LOCKED', fg, c(8)),
            'nav': ('NORMAL', bg, c(2)),
            'pane': ('PANE', bg, c(4)),
            'tab': ('TAB', bg, c(3)),
            'resize': ('RESIZE', bg, c(1)),
            'scroll': ('SCROLL', bg, c(6)),
            'move': ('MOVE', bg, c(5)),
        }
    except Exception:
        return FALLBACK_MODES


def _mode_name() -> str:
    try:
        stack = get_boss().mappings.keyboard_mode_stack
        return stack[-1].name if stack else ''
    except Exception:
        return ''


def _draw_mode_cell(screen: Screen) -> None:
    name = _mode_name()
    modes = _mode_styles()
    default = (name.upper() or '?', modes['nav'][1], modes['nav'][2])
    label, fg, bg = modes.get(name, default)
    orig = screen.cursor.fg, screen.cursor.bg, screen.cursor.bold
    screen.cursor.fg = as_rgb(fg)
    screen.cursor.bg = as_rgb(bg)
    screen.cursor.bold = True
    screen.draw(f' {label} ')
    screen.cursor.fg, screen.cursor.bg, screen.cursor.bold = orig
    screen.draw(' ')


def _compose_renamed(tab_obj) -> 'str | None':
    """Tab title composed from its *renamed* panes, joined by ' ~ '
    (e.g. 'proj1 ~ proj4'). Returns None — keep kitty's default title — when the
    tab was named by hand (ctrl+g t r sets tab.name) or no pane was renamed, so
    un-curated tabs look exactly as before. A renamed pane has override_title set;
    un-renamed panes only show their cwd (set via PS1) and are skipped."""
    if (getattr(tab_obj, 'name', '') or '').strip():
        return None
    names = []
    for window in tab_obj:
        name = (getattr(window, 'override_title', None) or '').strip()
        if name and (not names or names[-1] != name):  # skip blanks + adjacent dups
            names.append(name)
    return ' ~ '.join(names) or None


def _auto_tab_title(tab: TabBarData) -> 'str | None':
    """Resolve the TabBarData to its live kitty Tab and compose from its renamed
    panes. Fully guarded: any drift falls back to kitty's default title."""
    try:
        tab_obj = get_boss().tab_for_id(tab.tab_id)
        return _compose_renamed(tab_obj) if tab_obj is not None else None
    except Exception:
        return None


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    if index == 1:
        _draw_mode_cell(screen)
    auto = _auto_tab_title(tab)
    if auto:
        tab = tab._replace(title=auto)
    return draw_tab_with_powerline(
        draw_data, screen, tab, before, max_title_length, index, is_last, extra_data
    )
