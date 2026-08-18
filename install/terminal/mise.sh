#!/bin/bash

# Install mise for managing multiple versions of languages. See https://mise.jdx.dev/
sudo apt update -y && sudo apt install -y extrepo
sudo extrepo enable mise
sudo apt update
sudo apt install -y mise
