#!/bin/bash

# Update Omakub and run every migration that has not yet run on this machine.
#
# Migrations are tracked by filename in a state ledger — NOT inferred from git
# commit dates. The old scheme compared each migration's <epoch>.sh filename
# against the commit date of HEAD-before-pull and ran only the newer ones. That
# silently and permanently skipped a migration whenever HEAD had been advanced
# past its timestamp out of band: a bare `git pull`, or simply another commit
# landing minutes after the migration's filename epoch. The pre-pull commit date
# was then already newer than the migration, so it counted as "already applied"
# and never ran (this is how atuin, yazi, and the kitty switch were all missed).
# Recording what actually ran removes that failure mode for good.

cd $OMAKUB_PATH
last_updated_at=$(git log -1 --format=%cd --date=unix)
git pull

applied="${XDG_STATE_HOME:-$HOME/.local/state}/omakub/applied-migrations"
mkdir -p "$(dirname "$applied")"

# First run under this scheme: backfill the ledger with every migration the old
# commit-date logic would already have treated as applied, so existing machines
# don't re-run their whole history — some migrations are destructive on re-run
# (e.g. the kitty switch resets the theme once its source configs are gone).
# Genuinely-pending catch-up migrations carry timestamps newer than any pulled
# commit, so they fall through the backfill and still run in the loop below.
if [ ! -f "$applied" ]; then
  touch "$applied"
  for file in $OMAKUB_PATH/migrations/*.sh; do
    filename=$(basename "$file")
    [ "${filename%.sh}" -le "$last_updated_at" ] && echo "$filename" >>"$applied"
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
