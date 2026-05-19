#!/usr/bin/env bash
# Claude Code status line — mirrors Powerlevel10k p10k-classic segments:
#   left:  dir | git status
#   right: model | context usage | time

# ANSI colors as real escape bytes (so they survive being passed through %s).
ESC=$'\033'
BLUE="${ESC}[34m"
CYAN="${ESC}[36m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
GREY="${ESC}[90m"
RESET="${ESC}[0m"

input=$(cat)

# --- directory ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
home="$HOME"
dir="${cwd/#$home/~}"

# --- git branch & dirty marker ---
git_info=""
if branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  dirty=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain 2>/dev/null | head -1)
  if [ -n "$dirty" ]; then
    git_info=" ${YELLOW}(${branch} *)${RESET}"
  else
    git_info=" ${GREEN}(${branch})${RESET}"
  fi
fi

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

# --- context usage ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_info=""
if [ -n "$used_pct" ]; then
  ctx_info=" ctx:$(printf '%.0f' "$used_pct")%"
fi

# --- rate limits ---
rate_info=""
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$five" ]; then
  rate_info="$rate_info 5h:$(printf '%.0f' "$five")%"
fi
if [ -n "$week" ]; then
  rate_info="$rate_info 7d:$(printf '%.0f' "$week")%"
fi

# --- time ---
timestamp=$(date +%H:%M:%S)

# --- assemble ---
printf '%s%s%s%s  %s%s%s%s%s%s    %s%s%s' \
  "$BLUE" "$dir" "$RESET" "$git_info" \
  "$CYAN" "$model" "$RESET" \
  "$GREY" "$ctx_info$rate_info" "$RESET" \
  "$GREY" "$timestamp" "$RESET"
