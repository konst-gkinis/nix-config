#!/usr/bin/env bash
# Claude Code status line — powerline style, ayu color scheme.
# Segments (left -> right): dir | model | context | 5h | 7d | time
# Each segment is a colored block separated by the powerline arrow ().

esc=$'\033'
reset="${esc}[0m"
sep=$'\xee\x82\xb0'   # U+E0B0 nerd-font right-pointing powerline separator

# Nerd-font icons (FontAwesome range — present in any Nerd Font). Encoded as
# UTF-8 hex byte escapes so the Private Use Area glyphs can't be stripped.
ico_dir=$'\xef\x81\xbb'      # U+F07B folder
ico_model=$'\xef\x8b\x9b'    # U+F2DB microchip
ico_ctx=$'\xef\x82\x80'      # U+F080 bar chart
ico_rate=$'\xef\x88\x81'     # U+F201 line chart
ico_time=$'\xef\x80\x97'     # U+F017 clock

# Ayu dark palette.
ayu_ink="#0b0e14"     # dark fg for vivid backgrounds
ayu_fg="#bfbdb6"      # light fg for muted backgrounds
ayu_orange="#ff8f40"  # directory
ayu_blue="#59c2ff"    # model
ayu_grey="#565b66"    # context (normal)
ayu_yellow="#e6b450"  # context (warning)
ayu_red="#d95757"     # context (critical)
ayu_purple="#d2a6ff"  # 5h
ayu_green="#aad94c"   # 7d
ayu_special="#e6b673" # time

input=$(cat)

# #rrggbb -> "r;g;b" for ANSI truecolor.
hex2rgb() {
  local h=${1#\#}
  printf '%d;%d;%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# Fish-style path: home -> ~, every parent component shortened to its first
# char (dotted dirs keep the dot), last component kept in full.
fish_path() {
  local p="${1/#$HOME/\~}"
  local absolute=0
  [[ "$p" == /* ]] && absolute=1
  local IFS='/'
  read -ra parts <<<"$p"
  local rendered=() i seg
  local n=${#parts[@]}
  for i in "${!parts[@]}"; do
    seg="${parts[i]}"
    [ -z "$seg" ] && continue
    if [ "$i" -eq "$((n-1))" ]; then
      rendered+=("$seg")
    elif [ "$seg" = "~" ]; then
      rendered+=("~")
    elif [[ "$seg" == .* ]]; then
      rendered+=("${seg:0:2}")
    else
      rendered+=("${seg:0:1}")
    fi
  done
  local result="${rendered[*]}"
  [ "$absolute" -eq 1 ] && result="/$result"
  printf '%s' "$result"
}

# Segment store: parallel arrays of bg/fg/text.
seg_bg=(); seg_fg=(); seg_tx=()
add_segment() { seg_bg+=("$1"); seg_fg+=("$2"); seg_tx+=("$3"); }

# --- directory (fish style) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
add_segment "$ayu_orange" "$ayu_ink" "${ico_dir} $(fish_path "$cwd")"

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
add_segment "$ayu_blue" "$ayu_ink" "${ico_model} ${model}"

# --- context usage (bg shifts to warn/critical as it fills) ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  pct=$(printf '%.0f' "$used_pct")
  if   [ "$pct" -ge 90 ]; then ctx_bg="$ayu_red";    ctx_fg="$ayu_ink"
  elif [ "$pct" -ge 80 ]; then ctx_bg="$ayu_yellow"; ctx_fg="$ayu_ink"
  else                         ctx_bg="$ayu_grey";   ctx_fg="$ayu_fg"
  fi
  add_segment "$ctx_bg" "$ctx_fg" "${ico_ctx} ${pct}%"
fi

# --- rate limits ---
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
[ -n "$five" ] && add_segment "$ayu_purple" "$ayu_ink" "${ico_rate} 5h $(printf '%.0f' "$five")%"
[ -n "$week" ] && add_segment "$ayu_green"  "$ayu_ink" "${ico_rate} 7d $(printf '%.0f' "$week")%"

# --- time ---
add_segment "$ayu_special" "$ayu_ink" "${ico_time} $(date +%H:%M:%S)"

# --- render the powerline chain ---
out=""
prev_bg=""
for i in "${!seg_bg[@]}"; do
  bg=$(hex2rgb "${seg_bg[i]}")
  fg=$(hex2rgb "${seg_fg[i]}")
  # separator carries the previous bg as its fg, the current bg as its bg
  [ -n "$prev_bg" ] && out+="${esc}[38;2;${prev_bg}m${esc}[48;2;${bg}m${sep}"
  out+="${esc}[48;2;${bg}m${esc}[38;2;${fg}m ${seg_tx[i]} "
  prev_bg=$bg
done
# trailing cap: arrow in the last bg's color over the terminal background
out+="${reset}${esc}[38;2;${prev_bg}m${sep}${reset}"

printf '%s' "$out"
