#!/bin/bash

# Pin zellij back to 0.43.1: 0.44.x's built-in compact bar self-spins
# (plugin-exec + screen threads peg multiple cores at idle). 0.43.1 felt
# much better. No-op once already on 0.43.1.

if zellij --version 2>/dev/null | grep -q "0.43.1"; then
  echo "zellij already at 0.43.1, skipping downgrade"
else
  cd /tmp
  wget -O zellij.tar.gz "https://github.com/zellij-org/zellij/releases/download/v0.43.1/zellij-x86_64-unknown-linux-musl.tar.gz"
  tar -xf zellij.tar.gz zellij
  sudo install zellij /usr/local/bin
  rm zellij.tar.gz zellij
  cd -
  echo "zellij downgraded to 0.43.1 — restart your zellij sessions to pick it up"
fi
