#!/usr/bin/env bash
# Pick a repo from the homelab git backup with fzf and clone it (shallow by default).
# The list comes from `ssh pvegit list`, a git-shell command on pve; see git-backup.md in the
# homelab repo. Packaged in shared/packages.nix, so it runs as `git backup-clone`.
# Usage: git backup-clone [--full] [git-clone args...]    e.g. git backup-clone ~/src/foo
set -euo pipefail
depth=(--depth=1)
if [ "${1:-}" = --full ]; then
  depth=()
  shift
fi

repos=$(ssh -o BatchMode=yes -o ConnectTimeout=10 pvegit list)
[ -n "$repos" ] || { echo "no repos on pvegit" >&2; exit 1; }
name=$(fzf --prompt='pvegit> ' --height=40% --reverse <<<"$repos") || exit 130

git clone "${depth[@]}" "pvegit:$name.git" "$@"
