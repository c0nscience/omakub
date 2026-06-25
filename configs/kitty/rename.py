"""Rename the focused pane (window) or the active tab by editing its title in
nvim, replacing kitty's one-line set_window_title / set_tab_title prompt.

Two phases are needed because a kitten's main() runs in an *overlay* window, so
it cannot tell which pane it was launched over; only handle_result() receives the
real target window id:

  Phase 1 (kitten): handle_result() gets target_window_id from kitty and opens an
    nvim overlay over that window via remote control, passing the id along.
  Phase 2 (plain program, inside the overlay): reads the current title for that
    id (kitten @ ls), lets you edit it in nvim, then writes it back
    (kitten @ set-window-title / set-tab-title --match id:<id>). Saving an empty
    buffer resets the title to kitty's automatic one.

Phase 2 talks to kitty over the remote-control socket, so it needs
`allow_remote_control socket-only` + `listen_on` in kitty.conf (added there).

Usage in kitty.conf:
  map --mode pane c combine : kitten rename.py window : pop_keyboard_mode
  map --mode tab  r combine : kitten rename.py tab    : pop_keyboard_mode
"""

import json
import os
import shlex
import subprocess
import sys
import tempfile


def _kitten():
    """Locate the kitten binary by hand: the overlay's PATH may not include
    kitty's install dir."""
    for path in (
        os.path.expanduser("~/.local/bin/kitten"),
        os.path.expanduser("~/.local/kitty.app/bin/kitten"),
    ):
        if os.access(path, os.X_OK):
            return path
    return "kitten"


def _current_title(kind, target):
    """Current title of the target window, or of the tab that contains it."""
    try:
        out = subprocess.run(
            [_kitten(), "@", "ls"], capture_output=True, text=True, check=True
        ).stdout
        tree = json.loads(out)
    except Exception:
        return ""
    for osw in tree:
        for tab in osw.get("tabs", []):
            for win in tab.get("windows", []):
                if win.get("id") == target:
                    holder = tab if kind == "tab" else win
                    return holder.get("title", "") or ""
    return ""


def _set_cmd(kind, target, title):
    """Build the `kitten @` argv that sets (or, for empty title, resets) a title.
    Kept pure so it can be unit-tested without a running kitty."""
    k = _kitten()
    if kind == "tab":
        cmd = [k, "@", "set-tab-title", f"--match=window_id:{target}"]
        if title:
            cmd.append(title)  # empty -> kitty falls back to the active window
        return cmd
    if title:
        return [k, "@", "set-window-title", f"--match=id:{target}", title]
    # empty -> revert to the auto title and let programs update it again (cwd)
    return [k, "@", "set-window-title", "--temporary", f"--match=id:{target}"]


def _edit(kind, target):
    initial = _current_title(kind, target)
    fd, path = tempfile.mkstemp(prefix="kitty-rename-", suffix=".txt")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(initial)
        subprocess.run(
            ["nvim", "-n", "-c", "set laststatus=0 nonumber nolist",
             "-c", "startinsert!", path],
            check=False,
        )
        with open(path) as handle:
            lines = handle.read().splitlines()
    finally:
        os.unlink(path)
    subprocess.run(_set_cmd(kind, target, lines[0].strip() if lines else ""),
                   check=False)


# Phase 2: launched as `python3 rename.py --edit <kind> <id>` inside the overlay.
# This runs before the kitten-only import below, so it works under plain python3.
if __name__ == "__main__" and sys.argv[1:2] == ["--edit"]:
    _edit(sys.argv[2], int(sys.argv[3]))
    sys.exit(0)


# Phase 1: kitty imports this module (so __name__ != "__main__") and calls
# main() then handle_result().
from kittens.tui.handler import result_handler  # noqa: E402


def main(args):
    return None


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    kind = args[1] if len(args) > 1 else "window"
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    inner = "exec python3 {} --edit {} {}".format(
        shlex.quote(os.path.realpath(__file__)), shlex.quote(kind),
        int(target_window_id),
    )
    boss.call_remote_control(window, (
        "launch", "--type=overlay", f"--match=id:{target_window_id}",
        "--", "bash", "-lc", inner,
    ))
