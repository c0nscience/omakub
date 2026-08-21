#!/bin/bash

# Apply the file-indexer tuning to machines installed before
# install/desktop/set-gnome-indexing.sh existed. The installer is three
# `gsettings set` calls behind a schema guard, so sourcing it keeps the values in
# one place, re-running it is a no-op, and a machine without the indexer (or
# without a desktop at all) falls straight through the guard.
#
# No daemon restart on purpose. `index-on-battery` is watched at runtime and its
# handler re-reads `throttle` when it fires, so flipping it here applies both
# live; `initial-sleep` only ever mattered at startup and picks up at next login.
# Restarting tracker-miner-fs instead would force a full mtime re-crawl of the
# index — the exact kind of burst this change exists to avoid.
source $OMAKUB_PATH/install/desktop/set-gnome-indexing.sh
