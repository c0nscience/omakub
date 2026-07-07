#!/bin/bash

# Guard omakub's interactive shell setup against GDM's login-time ".profile"
# error popup. At graphical login /etc/gdm3/Xsession sources ~/.profile in a
# NON-interactive bash; that used to run ~/.bashrc -> defaults/bash/rc ->
# defaults/bash/init -> `atuin init bash`, whose readline `bind` prints
# "bind: warning: line editing not enabled" to stderr. GDM raises its
# config-error dialog on ANY stderr from ~/.profile (it tests `[ -s "$ERR" ]`,
# not the exit code), mislabeled "Error found when loading ~/.profile".
#
# The actual fix ships in defaults/bash/init, which now returns early in
# non-interactive shells (delivered by this update's `git pull`). This migration
# only reconciles machines that carried a temporary hand-added guard in
# ~/.bashrc: it restores the canonical unguarded `source .../rc` now that init
# self-guards. Idempotent, and a no-op on machines that never had the guard.
bashrc="$HOME/.bashrc"
if [ -f "$bashrc" ] && grep -q '# omakub-gdm-guard' "$bashrc"; then
  sed -i \
    -e '/^# omakub-gdm-guard:/d' \
    -e 's|^\[\[ \$- == \*i\* \]\] && source \(.*defaults/bash/rc\).*# omakub-gdm-guard$|source \1|' \
    "$bashrc"
  echo "Reverted temporary ~/.bashrc GDM guard; defaults/bash/init now self-guards."
fi
