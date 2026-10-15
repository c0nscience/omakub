#!/bin/bash

# Enable LazyVim's dotnet extra (omnisharp, csharpier, netcoredbg, neotest
# vstest). lazyvim.json is rewritten by :LazyExtras, so the extra is merged
# into the deployed list instead of copying the template over it.
lazyvim_json="$HOME/.config/nvim/lazyvim.json"
dotnet_extra="lazyvim.plugins.extras.lang.dotnet"
if [ -f "$lazyvim_json" ] && ! jq -e --arg extra "$dotnet_extra" '.extras | index($extra)' "$lazyvim_json" >/dev/null; then
  jq --arg extra "$dotnet_extra" '.extras = (.extras + [$extra] | sort)' "$lazyvim_json" >"$lazyvim_json.tmp" &&
    mv "$lazyvim_json.tmp" "$lazyvim_json"
  echo "Enabled the nvim dotnet extra. Restart nvim."
fi
