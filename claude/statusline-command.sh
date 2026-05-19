#!/usr/bin/env bash
# Claude Code status line — mirrors Powerlevel10k p10k-classic segments:
#   left:  dir | git status
#   right: model | context usage | user@host | time

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
    git_info=" \033[33m($branch *)\033[0m"
  else
    git_info=" \033[32m($branch)\033[0m"
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

# --- user@host ---
user_host="$(whoami)@$(hostname -s)"

# --- time ---
timestamp=$(date +%H:%M:%S)

# --- assemble ---
printf "\033[34m%s\033[0m%s  \033[36m%s\033[0m\033[90m%s%s\033[0m  \033[90m%s  %s\033[0m" \
  "$dir" "$git_info" "$model" "$ctx_info" "$rate_info" "$user_host" "$timestamp"
