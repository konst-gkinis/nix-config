#!/usr/bin/env bash
# halp: [-p] [-d] — read the last Claude Code session in $PAGER (-p pick one, -d this dir)
# Read a past Claude Code session without resuming it, from the transcripts Claude keeps in
# ~/.claude/projects/<cwd with non-alphanumerics as dashes>/<session-id>.jsonl.
# Shows your prompts, Claude's replies and a one-line summary of each tool call; thinking
# and tool output are left out. Packaged in shared/packages.nix.
# Usage: clog [-p|--pick] [-d|--here] [-n N]
#   (none)      the most recent session, any directory
#   -p, --pick  fzf over the last N (default 100) sessions, with a preview
#   -d, --here  only sessions started in the current directory
set -euo pipefail

root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
pick=0 here=0 limit=100

usage() { sed -n '7,10s/^# \{0,1\}//p' "$0"; }

render() { # render <file.jsonl>: the transcript as text, ANSI-coloured
  jq -r --arg file "$1" '
    def c($n; $s): "\u001b[\($n)m\($s)\u001b[0m";
    def clean: gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")
      | gsub("<command-name>(?<n>[^<]*)</command-name>[\\s\\S]*"; "\(.n)")
      | gsub("^\\s+|\\s+$"; "");
    def tool: "\(.name): " + (.input | (.description // .command // .file_path // .pattern
      // .url // .query // .prompt // tostring) | tostring | split("\n")[0] | .[0:120]);
    if .type == "user" and (.isMeta | not) and (.isSidechain | not) then
      .message.content
      | if type == "string" then clean
        else map(select(.type == "text") | .text | clean) | join("\n") end
      | select(length > 0 and (startswith("<") | not))
      | "\n" + c("1;36"; "❯ you") + "\n" + .
    elif .type == "assistant" and (.isSidechain | not) then
      .message.content[]
      | if .type == "text" then "\n" + c("1;33"; "⏺ claude") + "\n" + .text
        elif .type == "tool_use" then c("2"; "  ↳ " + tool)
        else empty end
    else empty end
  ' "$1" | if [ "${2:-}" = header ]; then
    printf '\033[1m%s\033[0m\n' "$1"; cat
  else cat; fi
}

sessions() { # newest first: <path>\t<date  project  title>
  local dir="$root" depth=2 # <project>/<session>.jsonl; deeper ones are subagents
  [ "$here" = 1 ] && dir="$root/${PWD//[^A-Za-z0-9]/-}" depth=1
  [ -d "$dir" ] || { echo "clog: no sessions in $dir" >&2; exit 1; }
  find "$dir" -mindepth "$depth" -maxdepth "$depth" -name '*.jsonl' \
    -printf '%T@\t%TY-%Tm-%Td %TH:%TM\t%p\n' | sort -rn | cut -f2- |
    while IFS=$'\t' read -r date f; do
      [ "$limit" -gt 0 ] || continue # keep reading: breaking would SIGPIPE the pipeline
      grep -q '"type":"user"' "$f" || continue
      title=$(grep -h '"type":"ai-title"' "$f" | tail -1 | jq -r .aiTitle)
      [ -n "$title" ] || title=$(grep -h '"type":"last-prompt"' "$f" | tail -1 | jq -r .lastPrompt)
      cwd=$(grep -h -m1 '"cwd":' "$f" | jq -r '.cwd // empty')
      printf '%s\t%s  %-36s  %s\n' "$f" "$date" "${cwd/#$HOME/\~}" "${title//$'\n'/ }"
      limit=$((limit - 1))
    done
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p | --pick) pick=1 ;;
    -d | --here) here=1 ;;
    -n) limit="$2"; shift ;;
    -h | --help) usage; exit 0 ;;
    --render) render "$2" header; exit ;; # fzf preview
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$pick" = 1 ]; then
  list=$(sessions)
  [ -n "$list" ] || { echo "clog: no sessions" >&2; exit 1; }
  file=$(fzf --delimiter='\t' --with-nth=2.. --ansi --reverse --prompt='session> ' \
    --preview "$0 --render {1}" --preview-window='right,60%,wrap' <<<"$list" | cut -f1) || exit 130
else
  limit=1
  file=$(sessions | cut -f1)
  [ -n "$file" ] || { echo "clog: no sessions" >&2; exit 1; }
fi

render "$file" header | sh -c "${PAGER:-less -R}"
