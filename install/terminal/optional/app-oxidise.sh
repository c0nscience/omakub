#!/bin/bash

# install cargo-binstall to speedup rust installations
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

# install rust tools
cargo binstall -y -q xh ripgrep bat eza zoxide fd-find mprocs bacon tokei sqlx-cli yazi-fm yazi-cli
cargo install --locked ncspot tree-sitter-cli

rustup component add rust-analyzer

mise use -g fzf@latest

# yazi was installed above (into ~/.cargo/bin); (re)generate its GNOME launcher
# now that the binary exists. Skip on terminal-only hosts. Run in a subshell with
# cargo's bin dir on PATH so Yazi.sh's `command -v yazi` guard sees it.
if [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
  (
    export PATH="$HOME/.cargo/bin:$PATH"
    source $OMAKUB_PATH/applications/Yazi.sh
  )
fi
