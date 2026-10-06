#!/bin/bash

# Default sqruff config: align column types and constraints in CREATE TABLE,
# and stop CP02 from re-casing identifiers. Only a deployed copy still
# identical to one omakub shipped earlier is replaced; an edited
# ~/.config/sqruff/.sqruff is kept.
sqruff_config="$HOME/.config/sqruff/.sqruff"
if [ -f "$sqruff_config" ]; then
  case "$(sha256sum <"$sqruff_config" | cut -d' ' -f1)" in
  5ba186d3213b4530483c47aa152feabb1c69b7b8c0b4128d38dcfcb2728915e1 | 1c3e4534ff289cf0c8cbb13f99e2f2dee0e179cfebb9b74eaf3ba132318ee83f)
    cp "$OMAKUB_PATH/configs/sqruff/.sqruff" "$sqruff_config"
    echo "Updated sqruff config (aligned column types, identifiers keep their case). Restart nvim."
    ;;
  esac
fi
