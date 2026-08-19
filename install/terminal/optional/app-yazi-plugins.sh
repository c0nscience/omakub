#!/bin/bash

# Yazi plugins. Yazi itself ships in the oxidise bundle, which sources this file
# once its binary exists; the matching migration back-fills machines that
# already have yazi. Safe to re-run from the install menu: every step is
# guarded, and the yazi config is only ever appended to — a hand-edited
# yazi.toml/keymap.toml is never rewritten.
#
# ouch.yazi (https://github.com/ndtoan96/ouch) previews archives inline and
# compresses the selection with `C`. It shells out to the `ouch` binary, which
# oxidise installs alongside the other rust tools; the guard below covers a
# standalone run of this script on a machine that predates that.

# Body runs in a subshell so the PATH tweak and the early bail-out don't leak
# into the sourcing installer.
(
  export PATH="$HOME/.cargo/bin:$PATH"

  if ! command -v ya &>/dev/null; then
    echo "Yazi is not installed — skipping its plugins (install the Oxidise bundle first)."
    exit 0
  fi

  command -v ouch &>/dev/null || cargo binstall -y -q ouch

  yazi_config="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
  mkdir -p "$yazi_config"

  [ -d "$yazi_config/plugins/ouch.yazi" ] || ya pkg add ndtoan96/ouch

  # Archive preview. Appended as its own array-of-tables entry so it stays valid
  # TOML whether or not the file already declares a [plugin] table.
  if ! grep -qs 'run *= *"ouch"' "$yazi_config/yazi.toml"; then
    cat >>"$yazi_config/yazi.toml" <<'EOF'

[[plugin.prepend_previewers]]
mime = "application/{*zip,tar,bzip2,7z*,rar,xz,zstd,java-archive}"
run  = "ouch"
EOF
  fi

  # Compress the selection. C is unbound in yazi's default keymap (c is the
  # copy-path prefix), so this only adds a binding.
  if ! grep -qs 'plugin ouch' "$yazi_config/keymap.toml"; then
    cat >>"$yazi_config/keymap.toml" <<'EOF'

[[mgr.prepend_keymap]]
on   = "C"
run  = "plugin ouch"
desc = "Compress with ouch"
EOF
  fi
)
