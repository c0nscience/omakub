#!/usr/bin/env pwsh
# Claude Code status line — Windows port of statusline.sh.
#
# Same segments, same colors, same layout as the bash version, but with zero
# external dependencies: ConvertFrom-Json replaces jq and .NET formatting replaces
# awk. That matters here — a subprocess costs ~30ms on Windows and the bash script
# spawns ~20 of them per render. Measured end-to-end: 855ms for bash+jq, 371ms for
# this. It also handles the backslash paths Claude Code actually sends on Windows,
# which `basename` cannot.
#
# Wire it up (see install/terminal/claude-statusline.sh for the Linux twin):
#   "statusLine": { "type": "command",
#     "command": "pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:/Users/<you>/.claude/statusline-command.ps1" }
#
# Use FORWARD slashes in that path. When Git Bash is present Claude Code runs the
# statusline through it, so the command string is bash-parsed and backslashes are
# eaten as escapes — "C:\Users\Benni" silently becomes "C:UsersBenni" and the line
# just disappears. `~` is out too: bash expands it, `pwsh -File` doesn't.

# Invariant culture is the equivalent of the bash version's `export LC_NUMERIC=C`:
# without it a German/French locale renders the cost as "$1,23".
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
# Emit UTF-8 so the emoji survive the pipe back to Claude Code.
# (Throws when no console is attached; the redirected default is already UTF-8.)
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference = 'SilentlyContinue'
# Keep a nonzero `git` exit (e.g. "not a repo") from throwing, whatever the user's default is.
$PSNativeCommandUseErrorActionPreference = $false

# Never mention `$input` in this file: naming it anywhere makes PowerShell wire up
# the input pipeline and drain stdin, so this ReadToEnd would come back empty.
$raw = [Console]::In.ReadToEnd()
try { $data = $raw | ConvertFrom-Json } catch { $data = $null }
# Empty or unparseable stdin still renders a line rather than a blank statusline.
if ($null -eq $data) { $data = [pscustomobject]@{} }

# jq's `// default` — substitute when the field is absent.
function Def($value, $fallback) { if ($null -eq $value) { $fallback } else { $value } }

$MODEL   = Def $data.model.display_name '?'
$EFFORT  = Def $data.effort.level ''
$STYLE   = Def $data.output_style.name ''
$COST    = [double](Def $data.cost.total_cost_usd 0)
$DUR_MS  = [double](Def $data.cost.total_duration_ms 0)
$ADDED   = Def $data.cost.total_lines_added 0
$REMOVED = Def $data.cost.total_lines_removed 0
$USED    = [double](Def $data.context_window.total_input_tokens 0)
$SIZE    = [double](Def $data.context_window.context_window_size 200000)
$DIR     = Def $data.workspace.current_dir (Def $data.cwd '')

$E = [char]27

# 1500 -> "2k", 999 -> "999". F0 rounds half-to-even, matching awk's "%.0f";
# the sub-1000 branch truncates, matching awk's "%d".
function Fmt($n) {
  $n = [double]$n
  if ($n -ge 1000) { '{0:F0}k' -f ($n / 1000) } else { '{0:D}' -f [int][math]::Truncate($n) }
}
# color text by fullness: orange >=60%, red >=80%, else plain
function Clr($pct, $text) {
  if     ($pct -ge 80) { "$E[38;5;196m$text$E[0m" }
  elseif ($pct -ge 60) { "$E[38;5;208m$text$E[0m" }
  else                 { $text }
}
# wrap text in an SGR code, then reset:  Paint '38;5;46' "text"
function Paint($sgr, $text) { "$E[${sgr}m$text$E[0m" }
# static truecolor rainbow gradient across a string (red -> magenta). A
# statusline is re-run at most ~once/second, so it can't animate like the
# /effort menu — this is the closest "fancy" option (a fixed gradient).
function Rainbow($s) {
  $n = $s.Length
  $out = [Text.StringBuilder]::new()
  for ($i = 1; $i -le $n; $i++) {
    $hp = $(if ($n -gt 1) { ($i - 1) / ($n - 1) } else { 0 }) * 5
    $m = $hp - 2 * [math]::Floor($hp / 2)
    $a = [math]::Abs($m - 1)
    $x = 1 - $a
    switch ([int][math]::Floor($hp)) {
      0       { $r = 1;  $g = $x; $b = 0  }
      1       { $r = $x; $g = 1;  $b = 0  }
      2       { $r = 0;  $g = 1;  $b = $x }
      3       { $r = 0;  $g = $x; $b = 1  }
      4       { $r = $x; $g = 0;  $b = 1  }
      default { $r = 1;  $g = 0;  $b = $x }
    }
    # Truncate, not round — awk's "%d" truncates, and [int] would round-half-to-even.
    $rr = [int][math]::Truncate($r * 255)
    $gg = [int][math]::Truncate($g * 255)
    $bb = [int][math]::Truncate($b * 255)
    [void]$out.Append("$E[38;2;$rr;$gg;${bb}m" + $s[$i - 1])
  }
  [void]$out.Append("$E[0m")
  $out.ToString()
}

$CTXPCT = if ($SIZE -gt 0) { [int][math]::Round(100 * $USED / $SIZE, [MidpointRounding]::ToEven) } else { 0 }

# git branch (resolved from the working dir; silent if not a repo).
# Keep git out of a pipeline: piping into `Select-Object -First 1` stops the
# pipeline early and leaves $LASTEXITCODE unset, which reads as failure here.
$BRANCH = ''
if ($DIR -and (Test-Path -LiteralPath $DIR)) {
  $head = & git -C $DIR rev-parse --abbrev-ref HEAD 2>$null
  if ($LASTEXITCODE -eq 0 -and $head) { $BRANCH = ([string]@($head)[0]).Trim() }
}

# AVC agent handle — read only the working dir's own .avc (folder-scoped, no walk-up)
$AVC = ''
if ($DIR) {
  $avcFile = Join-Path $DIR '.avc'
  if (Test-Path -LiteralPath $avcFile -PathType Leaf) {
    # -cmatch, not -match: PowerShell's -match is case-insensitive, but the sed in
    # the bash twin is not, so plain `-match` would also accept `avc_handle=`.
    foreach ($line in (Get-Content -LiteralPath $avcFile)) {
      if ($line -cmatch '^\s*AVC_HANDLE=(.*)$') { $AVC = $Matches[1].Trim().Trim('"').Trim("'"); break }
    }
  }
}

# session duration, adaptive top-2 units
$span = [TimeSpan]::FromSeconds([math]::Floor($DUR_MS / 1000))
$DUR = if     ($span.Days    -gt 0) { "$($span.Days)d $($span.Hours)h" }
       elseif ($span.Hours   -gt 0) { "$($span.Hours)h $($span.Minutes)m" }
       elseif ($span.Minutes -gt 0) { "$($span.Minutes)m $($span.Seconds)s" }
       else                         { "$($span.Seconds)s" }

# 5-hour usage window values (subscription plans only); each empty if not applicable
$NOW = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$RESET5 = Def $data.rate_limits.five_hour.resets_at ''
$S5PCT  = Def $data.rate_limits.five_hour.used_percentage ''
$REMAIN = ''; $RESETAT = ''; $USEDPCT = ''
if ("$RESET5" -match '^\d+$' -and [long]$RESET5 -gt $NOW) {
  $rem = [long]$RESET5 - $NOW
  $rh = [math]::Floor($rem / 3600); $rm = [math]::Floor(($rem % 3600) / 60)
  $REMAIN = if ($rh -gt 0) { "${rh}h ${rm}m" } else { "${rm}m" }
  $RESETAT = [DateTimeOffset]::FromUnixTimeSeconds([long]$RESET5).ToLocalTime().ToString('HH:mm')
  # used_percentage is a float (e.g. 23.5), so round it rather than integer-matching
  # it — the bash twin's `^[0-9]+$` guard rejects floats and drops this segment.
  if ("$S5PCT" -ne '') {
    $p = [int][math]::Round([double]$S5PCT, [MidpointRounding]::ToEven)
    $USEDPCT = Clr $p "$p%"
  }
}

# --- status line segments: one per line; reorder or comment freely, joined by " | " ---
$seg = [Collections.Generic.List[string]]::new()

# model name — sonnet=green, opus=yellow, fable=red; others (haiku...) plain
$MODEL_C = switch -Regex ($MODEL.ToLower()) {
  'opus'   { Paint '38;5;226' $MODEL; break }
  'sonnet' { Paint '38;5;46'  $MODEL; break }
  'fable'  { Paint '38;5;196' $MODEL; break }
  default  { $MODEL }
}
# effort — high=green, xhigh=yellow, max=red + alarm; low/medium plain.
# For a rainbow max instead of flat red, swap the active `max` line for the
# commented one below (static gradient — a statusline can't animate).
# -CaseSensitive to match the bash `case`, which is.
$EFFORT_C = switch -Regex -CaseSensitive ($EFFORT) {
  '^max$'                    { "🚨 $(Paint '38;5;196' $EFFORT)"; break }
  # '^max$'                  { "🚨 $(Rainbow $EFFORT)"; break }
  '^(xhigh$|very|extra)'     { Paint '38;5;226' $EFFORT; break }
  '^high$'                   { Paint '38;5;46'  $EFFORT; break }
  default                    { $EFFORT }
}
$seg.Add($MODEL_C + $(if ($EFFORT_C) { " · $EFFORT_C" } else { '' }))
if ($AVC)   { $seg.Add("🤖 $(Paint '38;5;205' $AVC)") }
if ($STYLE -and $STYLE -ne 'default') { $seg.Add("🎨 $STYLE") }
if ($BRANCH) { $seg.Add($BRANCH) }
$seg.Add("🧠 $(Clr $CTXPCT "$(Fmt $USED)/$(Fmt $SIZE) $CTXPCT%")")
# $seg.Add("📝 +$ADDED/-$REMOVED")
$seg.Add("🕐 $DUR")                            # session elapsed (wall-clock)
# if ($REMAIN)  { $seg.Add("⏳$REMAIN") }       # 5h window: remaining
if ($RESETAT) { $seg.Add("🔄 $RESETAT") }      # 5h window: reset clock
if ($USEDPCT) { $seg.Add($USEDPCT) }           # 5h window: used %
$seg.Add('💰 $' + ('{0:F2}' -f $COST))
if ($DIR)     { $seg.Add("📁 $(Split-Path -Leaf $DIR)") }

[Console]::Out.Write(($seg -join ' | '))
[Console]::Out.Flush()
exit 0
