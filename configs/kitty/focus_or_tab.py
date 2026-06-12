"""Focus the neighboring kitty window; if already at the edge, fall through
to the previous/next tab. Replicates zellij's MoveFocusOrTab action.

Usage in kitty.conf:  map alt+h kitten focus_or_tab.py left
"""

from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    direction = args[1] if len(args) > 1 else 'right'
    tab = boss.active_tab
    if tab is None:
        return
    before = tab.active_window
    tab.neighboring_window(direction)
    if tab.active_window is before:
        if direction == 'left':
            boss.previous_tab()
        elif direction == 'right':
            boss.next_tab()
