#!/bin/bash

# opencode's own installer appends a PATH export to ~/.bashrc by default, which
# omakub does not own — shell config lives in defaults/bash/*. Install with
# --no-modify-path and link the binary into ~/.local/bin, which defaults/bash/shell
# already puts on PATH, so nothing scribbles in ~/.bashrc.
#
# Re-running installs the latest release, which is why the Update menu points at
# this same file. `opencode upgrade` self-updates the binary in place and leaves
# the symlink pointing at it, so both update paths work.
curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path

mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
