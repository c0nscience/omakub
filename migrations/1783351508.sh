#!/bin/bash

# Re-ship the atuin install for machines that advanced past migration
# 1782945037 without ever running it. Same bare-`git pull` trap as the kitty
# catch-up (1783335459): migrate.sh derives "already applied" from the pre-pull
# commit timestamp, so once HEAD moved past the atuin commit (f802ea7) that
# migration was skipped for good. Symptom: `command -v atuin` is false, so the
# shell-history integration in defaults/bash/init never activates. setup-atuin.sh
# is idempotent (mise pin + guarded config/bash-preexec/history-import), so this
# is a no-op once atuin is already in place.
source $OMAKUB_PATH/install/terminal/setup-atuin.sh
