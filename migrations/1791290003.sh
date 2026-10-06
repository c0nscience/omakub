#!/bin/bash

# SQL formatting moves from sqruff to sleek. sqruff has to parse a file in one
# dialect and strips the indentation of whatever it cannot parse, which is
# most real schemas (mixed or vendor syntax); sleek formats token by token and
# needs no dialect. The default sqruff config shipped earlier is removed
# unless it was edited. Re-copying sql.lua is idempotent.
nvim_plugins="$HOME/.config/nvim/lua/plugins"
if [ -d "$nvim_plugins" ]; then
  cp "$OMAKUB_PATH/configs/neovim/sql.lua" "$nvim_plugins/sql.lua"
  echo "Updated nvim SQL config (sleek formats SQL). Restart nvim."
fi

sqruff_config="$HOME/.config/sqruff/.sqruff"
if [ -f "$sqruff_config" ]; then
  case "$(sha256sum <"$sqruff_config" | cut -d' ' -f1)" in
  5ba186d3213b4530483c47aa152feabb1c69b7b8c0b4128d38dcfcb2728915e1 | 1c3e4534ff289cf0c8cbb13f99e2f2dee0e179cfebb9b74eaf3ba132318ee83f | d7a799ce25385c220294303c80e08c49c8f1833232e236c48cfa3b331d07e3bd)
    rm "$sqruff_config"
    rmdir --ignore-fail-on-non-empty "$HOME/.config/sqruff"
    ;;
  esac
fi
