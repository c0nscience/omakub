#!/bin/bash

mkdir -p ~/.config/1Password/ssh
cp ~/.local/share/omakub/configs/ssh/agent.toml ~/.config/1Password/ssh/

mkdir ~/.ssh
cp ~/.local/share/omakub/configs/ssh/config ~/.ssh/
