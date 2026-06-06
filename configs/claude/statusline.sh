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
# color text by fullness: orange >=60%, red >=80%, else plain
clr() {
  if   [ "$1" -ge 80 ]; then printf '\033[38;5;196m%s\033[0m' "$2"
  elif [ "$1" -ge 60 ]; then printf '\033[38;5;208m%s\033[0m' "$2"
  else                       printf '%s' "$2"
  fi
}
CTXPCT=$(awk -v u="$USED" -v s="$SIZE" 'BEGIN{printf "%.0f", (s>0)?100*u/s:0}')

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

# 5-hour usage session: remaining + reset clock + used% (subscription plans only)
NOW=$(date +%s)
RESET5=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
S5PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SESS=""
if [[ "$RESET5" =~ ^[0-9]+$ ]] && [ "$RESET5" -gt "$NOW" ]; then
  REM=$((RESET5 - NOW)); RH=$((REM / 3600)); RM=$(((REM % 3600) / 60))
  [ "$RH" -gt 0 ] && LEFT="${RH}h ${RM}m" || LEFT="${RM}m"
  SESS="⏳$LEFT ↻ $(date -d @"$RESET5" +%H:%M)"
  [[ "$S5PCT" =~ ^[0-9]+$ ]] && SESS="$SESS $(clr "$S5PCT" "${S5PCT}%")"
fi

out="$MODEL${EFFORT:+ · $EFFORT}"
[ -n "$STYLE" ] && [ "$STYLE" != "default" ] && out="$out 🎨 $STYLE"
[ -n "$BRANCH" ] && out="$out  $BRANCH"
out="$out | 🧠 $(clr "$CTXPCT" "$(fmt $USED)/$(fmt $SIZE) ${CTXPCT}%")"
out="$out | 📝 +${ADDED}/-${REMOVED}"
out="$out | ⏱ $DUR${SESS:+ - $SESS}"
out="$out | 💰 \$$(printf '%.2f' "$COST")"
[ -n "$DIR" ] && out="$out | 📁 $(basename "$DIR")"

printf "%s" "$out"
