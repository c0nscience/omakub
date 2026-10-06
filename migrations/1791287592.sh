#!/bin/bash

# Align "as" aliases in SELECT lists in the default sqruff config. Only a
# deployed copy still identical to the one shipped by 1791287206 is replaced;
# an edited ~/.config/sqruff/.sqruff is kept.
sqruff_config="$HOME/.config/sqruff/.sqruff"
shipped_without_alias_alignment="5ba186d3213b4530483c47aa152feabb1c69b7b8c0b4128d38dcfcb2728915e1"
if [ -f "$sqruff_config" ] && [ "$(sha256sum <"$sqruff_config" | cut -d' ' -f1)" = "$shipped_without_alias_alignment" ]; then
  cp "$OMAKUB_PATH/configs/sqruff/.sqruff" "$sqruff_config"
  echo "Updated sqruff config (aligned select aliases). Restart nvim."
fi
