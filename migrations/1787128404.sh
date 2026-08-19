#!/bin/bash

# Ship the ouch.yazi plugin (inline archive preview, `C` to compress) to
# machines that already installed yazi with the oxidise bundle. The installer
# no-ops when yazi is absent, and only appends config blocks it can't find.
source $OMAKUB_PATH/install/terminal/optional/app-yazi-plugins.sh
