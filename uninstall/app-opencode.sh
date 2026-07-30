#!/bin/bash

# Mirror of install/terminal/optional/app-opencode.sh. ~/.config/opencode holds
# opencode's own global config and plugin deps, ~/.local/share/opencode its
# auth.json, session storage and logs — both go, matching how the other
# manually-installed apps are uninstalled here.
#
# The opencode-sec profile lives in the omakub repo (configs/opencode/sec.json)
# and survives this, as does the secret reference in ~/.config/op/opencode-sec.env.
rm -f ~/.local/bin/opencode
rm -rf ~/.opencode ~/.config/opencode ~/.local/share/opencode
