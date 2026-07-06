#!/bin/bash

# Update Omakub and run every migration that has not yet run on this machine.
#
# Migrations are tracked by filename in a state ledger — NOT inferred from git
# commit dates. The old scheme compared each migration's <epoch>.sh filename
# against the commit date of HEAD-before-pull and ran only newer ones, which
# silently and permanently skipped any migration once HEAD had advanced past its
# timestamp out of band (a bare `git pull`, or simply another commit landing
# after the migration's filename epoch). Recording what actually ran removes that
# failure mode: a migration runs once, is written to the ledger, and is skipped
# thereafter regardless of how HEAD moved.

cd $OMAKUB_PATH
git pull

applied="${XDG_STATE_HOME:-$HOME/.local/state}/omakub/applied-migrations"
mkdir -p "$(dirname "$applied")"

# First run under this scheme (no ledger yet): seed the ledger with the whole
# pre-ledger history so existing machines don't re-run it — some of it is
# destructive on re-run (1781289040 resets the theme once its source configs are
# gone). The cutoff is a FIXED epoch just below the newest migrations that
# existed when the ledger shipped (the atuin catch-up 1783351508 and yazi
# catch-up 1783351769); everything at or before it is treated as already
# applied. Crucially this is NOT keyed to HEAD's commit date: deriving it from
# HEAD reopened the very skip trap this rewrite closes, because two commits
# landed after the catch-ups and pushed HEAD's date past them, so a clone
# advanced out of band would backfill the pending catch-ups as already-applied
# and never run them. A fixed baseline lets everything after it (the catch-ups,
# and future migrations, all idempotent by convention) fall through and run once.
ledger_baseline=1783351507
if [ ! -f "$applied" ]; then
  touch "$applied"
  for file in $OMAKUB_PATH/migrations/*.sh; do
    filename=$(basename "$file")
    [ "${filename%.sh}" -le "$ledger_baseline" ] && echo "$filename" >>"$applied"
  done
fi

for file in $OMAKUB_PATH/migrations/*.sh; do
  filename=$(basename "$file")

  grep -qxF "$filename" "$applied" && continue

  echo "Running migration for ${filename%.sh}"
  source "$file"
  echo "$filename" >>"$applied"
done

cd - >/dev/null
