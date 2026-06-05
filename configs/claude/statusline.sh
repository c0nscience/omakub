#!/usr/bin/env bash
export LC_NUMERIC=C
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
STYLE=$(echo "$input" | jq -r '.output_style.name // empty')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DUR_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
USED=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

fmt() { awk -v n="$1" 'BEGIN{printf (n>=1000)?"%.0fk":"%d", (n>=1000)?n/1000:n}'; }

# git branch (resolved from the working dir; silent if not a repo)
BRANCH=""
if [ -n "$DIR" ]; then
  BRANCH=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# session duration, adaptive top-2 units (date handles all rollover)
SECS=$((DUR_MS / 1000))
read -r J H M S <<<"$(date -u -d@"$SECS" +'%-j %-H %-M %-S')"
D=$((J - 1))
if   [ "$D" -gt 0 ]; then DUR="${D}d ${H}h"
elif [ "$H" -gt 0 ]; then DUR="${H}h ${M}m"
elif [ "$M" -gt 0 ]; then DUR="${M}m ${S}s"
else                      DUR="${S}s"
fi

out="$MODEL${EFFORT:+ · $EFFORT}"
[ -n "$STYLE" ] && [ "$STYLE" != "default" ] && out="$out 🎨 $STYLE"
[ -n "$BRANCH" ] && out="$out  $BRANCH"
out="$out | 🧠 $(fmt $USED)/$(fmt $SIZE)"
out="$out | 📝 +${ADDED}/-${REMOVED}"
out="$out | ⏱ $DUR"
out="$out | 💰 \$$(printf '%.2f' "$COST")"
[ -n "$DIR" ] && out="$out | 📁 $(basename "$DIR")"

printf "%s" "$out"
