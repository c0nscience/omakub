#!/bin/bash

# Turn on the atuin command-loss trace shipped in defaults/bash/init.
#
# Comparing ~/.bash_history against atuin's history.db showed ~5% of executed
# commands never reaching atuin -- no error, no log line, nothing. atuin's own
# hook runs `atuin history start ... 2>/dev/null`, so a refused or failed write
# is discarded silently, which is why this went unnoticed for weeks.
#
# The trace records both sides of that boundary. It only takes effect in shells
# started after this update, so existing panes stay untraced.
mkdir -p "$HOME/.local/state/omakub"

cat <<'NOTE'

  Atuin command-loss tracing is now enabled.

    log:  ~/.local/state/omakub/atuin-trace.log
    off:  export OMAKUB_ATUIN_TRACE=0

  Open a NEW terminal window for it to take effect -- panes that are already
  running keep the old, untraced hooks.

  When a command goes missing from ctrl+r again, grep the log for it:

    grep -F '<the command>' ~/.local/state/omakub/atuin-trace.log

    EXEC ... id=<uuid>   atuin accepted the write; the loss is downstream
    EXEC ... id=EMPTY    atuin refused or failed the write
    (no EXEC line)       the preexec hook never fired for that command

NOTE
