#!/bin/bash

# install cargo-binstall to speedup rust installations
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

# install rust tools
cargo binstall -q xh ripgrep bat eza zoxide fd-find mprocs bacon tokei
cargo install --locked ncspot tree-sitter-cli

rustup component add rust-analyzer
