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
# wrap text in an SGR code, then reset:  paint '38;5;46' "text"
paint() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
# static truecolor rainbow gradient across a string (red -> magenta). A
# statusline is re-run at most ~once/second, so it can't animate like the
# /effort menu — this is the closest "fancy" option (a fixed gradient).
rainbow() {
  awk -v s="$1" 'BEGIN{
    n=length(s);
    for(i=1;i<=n;i++){
      hp=((n>1)?(i-1)/(n-1):0)*5;
      m=hp-2*int(hp/2); a=m-1; if(a<0)a=-a; x=1-a;
      seg=int(hp);
      if(seg==0){r=1;g=x;b=0} else if(seg==1){r=x;g=1;b=0}
      else if(seg==2){r=0;g=1;b=x} else if(seg==3){r=0;g=x;b=1}
      else if(seg==4){r=x;g=0;b=1} else {r=1;g=0;b=x}
      printf "\033[38;2;%d;%d;%dm%s", r*255,g*255,b*255, substr(s,i,1);
    }
    printf "\033[0m";
  }'
}
CTXPCT=$(awk -v u="$USED" -v s="$SIZE" 'BEGIN{printf "%.0f", (s>0)?100*u/s:0}')

# git branch (resolved from the working dir; silent if not a repo)
BRANCH=""
if [ -n "$DIR" ]; then
  BRANCH=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# AVC agent handle — read only the working dir's own .avc (folder-scoped, no walk-up)
AVC=""
if [ -n "$DIR" ] && [ -r "$DIR/.avc" ]; then
  AVC=$(sed -n 's/^[[:space:]]*AVC_HANDLE=//p' "$DIR/.avc" | head -n1)
  AVC=${AVC%\"}; AVC=${AVC#\"}
  AVC=${AVC%\'}; AVC=${AVC#\'}
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

# 5-hour usage window values (subscription plans only); each empty if not applicable
NOW=$(date +%s)
RESET5=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
S5PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
REMAIN="" RESETAT="" USEDPCT=""
if [[ "$RESET5" =~ ^[0-9]+$ ]] && [ "$RESET5" -gt "$NOW" ]; then
  REM=$((RESET5 - NOW)); RH=$((REM / 3600)); RM=$(((REM % 3600) / 60))
  [ "$RH" -gt 0 ] && REMAIN="${RH}h ${RM}m" || REMAIN="${RM}m"
  RESETAT=$(date -d @"$RESET5" +%H:%M)
  [[ "$S5PCT" =~ ^[0-9]+$ ]] && USEDPCT=$(clr "$S5PCT" "${S5PCT}%")
fi

# --- status line segments: one per line; reorder or comment freely, joined by " | " ---
seg=()

# model name — sonnet=green, opus=yellow, fable=red; others (haiku…) plain
case "$(printf '%s' "$MODEL" | tr '[:upper:]' '[:lower:]')" in
  *opus*)   MODEL_C=$(paint '38;5;226' "$MODEL") ;;
  *sonnet*) MODEL_C=$(paint '38;5;46'  "$MODEL") ;;
  *fable*)  MODEL_C=$(paint '38;5;196' "$MODEL") ;;
  *)        MODEL_C="$MODEL" ;;
esac
# effort — high=green, xhigh=yellow, max=red + 🚨 alarm; low/medium plain.
# For a rainbow max instead of flat red, swap the active `max)` line for the
# commented one below (static gradient — a statusline can't animate).
EFFORT_C=""
case "$EFFORT" in
  max)                EFFORT_C="🚨 $(paint '38;5;196' "$EFFORT")" ;;
  # max)              EFFORT_C="🚨 $(rainbow "$EFFORT")" ;;
  xhigh|very*|extra*) EFFORT_C=$(paint '38;5;226' "$EFFORT") ;;
  high)               EFFORT_C=$(paint '38;5;46'  "$EFFORT") ;;
  *)                  EFFORT_C="$EFFORT" ;;
esac
seg+=("$MODEL_C${EFFORT_C:+ · $EFFORT_C}")
[ -n "$AVC" ] && seg+=("🤖 $(printf '\033[38;5;205m%s\033[0m' "$AVC")")
[ -n "$STYLE" ] && [ "$STYLE" != "default" ] && seg+=("🎨 $STYLE")
[ -n "$BRANCH" ] && seg+=("$BRANCH")
seg+=("🧠 $(clr "$CTXPCT" "$(fmt $USED)/$(fmt $SIZE) ${CTXPCT}%")")
# seg+=("📝 +${ADDED}/-${REMOVED}")
seg+=("🕐 $DUR")                           # session elapsed (wall-clock)
# [ -n "$REMAIN" ]  && seg+=("⏳$REMAIN")    # 5h window: remaining
[ -n "$RESETAT" ] && seg+=("🔄 $RESETAT")  # 5h window: reset clock
[ -n "$USEDPCT" ] && seg+=("$USEDPCT")     # 5h window: used %
seg+=("💰 \$$(printf '%.2f' "$COST")")
[ -n "$DIR" ] && seg+=("📁 $(basename "$DIR")")

out=""; sep=""
for s in "${seg[@]}"; do out+="$sep$s"; sep=" | "; done
printf "%s" "$out"
