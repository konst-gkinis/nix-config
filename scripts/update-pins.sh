#!/usr/bin/env bash
# halp: bump fetchFromGitHub pins marked "# nup --pins: follow ..." (--check: dry run)
#
# A pin opts in with a marker comment on the line directly above its
# `fetchFromGitHub {`:
#
#   # nup --pins: follow main      track the head of a branch (rev = commit)
#   # nup --pins: follow tags      track the highest version tag (rev = tag)
#
# The owner, repo, rev and hash lines must sit inside that call, one per line.
# Pins without a marker (like the bat ayu theme) are never touched.
#
# Usage: update-pins.sh [--check] [DIR]   (DIR defaults to $NH_FLAKE, then .)
# Prints every changed file's path on stdout; progress goes to stderr.
# Refuses to run while a file holding a marked pin has uncommitted changes.
set -euo pipefail

check=false
if [[ ${1:-} == --check ]]; then
  check=true
  shift
fi
dir=${1:-${NH_FLAKE:-.}}
cd "$dir"

say() { printf '%s\n' "$*" >&2; }

# One line per marked pin: file, marker line, mode, then the line number and
# value of owner, repo, rev and hash, tab-separated.
list_pins() {
  git grep -l -E '^[[:space:]]*# nup --pins: follow ' -- '*.nix' | while read -r file; do
    awk -v file="$file" '
      function val(s) { sub(/^[^"]*"/, "", s); sub(/".*$/, "", s); return s }
      /^[[:space:]]*# nup --pins: follow / {
        mode = $NF; start = NR; owner = repo = rev = hash = ""; next
      }
      start && /^[[:space:]]*owner[[:space:]]*=/ { owner = NR "\t" val($0) }
      start && /^[[:space:]]*repo[[:space:]]*=/  { repo  = NR "\t" val($0) }
      start && /^[[:space:]]*rev[[:space:]]*=/   { rev   = NR "\t" val($0) }
      start && /^[[:space:]]*hash[[:space:]]*=/  { hash  = NR "\t" val($0) }
      start && /^[[:space:]]*}/ {
        if (owner == "" || repo == "" || rev == "" || hash == "")
          printf "%s:%d: marker is not followed by owner/repo/rev/hash\n", file, start > "/dev/stderr"
        else
          print file "\t" start "\t" mode "\t" owner "\t" repo "\t" rev "\t" hash
        start = 0
      }
    ' "$file"
  done
}

latest_rev() { # mode owner repo
  local url="https://github.com/$2/$3"
  case $1 in
    tags)
      git ls-remote --tags --refs --sort=-v:refname "$url" | head -1 | sed 's|.*refs/tags/||'
      ;;
    *)
      git ls-remote "$url" "refs/heads/$1" | cut -f1
      ;;
  esac
}

mapfile -t pins < <(list_pins)

# Check every file before editing any, so a refused run leaves nothing behind.
if ! $check; then
  dirty=$(printf '%s\n' "${pins[@]}" | cut -f1 | sort -u |
    while read -r f; do git diff --quiet HEAD -- "$f" || echo "$f"; done)
  if [[ -n $dirty ]]; then
    say "✗ uncommitted changes, commit or stash them first:"
    say "$dirty"
    exit 1
  fi
fi

changed=()
failed=0
for pin in "${pins[@]}"; do
  IFS=$'\t' read -r file line mode _ owner _ repo rev_line rev hash_line hash <<<"$pin"
  new_rev=$(latest_rev "$mode" "$owner" "$repo") || new_rev=""
  if [[ -z $new_rev ]]; then
    say "✗ $owner/$repo ($file:$line): no upstream rev for 'follow $mode'"
    failed=1
    continue
  fi
  if [[ $new_rev == "$rev" ]]; then
    say "  $owner/$repo: up to date ($rev)"
    continue
  fi
  if $check; then
    say "↑ $owner/$repo: $rev → $new_rev"
    continue
  fi
  new_hash=$(nix flake prefetch --json "github:$owner/$repo/$new_rev" | jq -r .hash)
  sed -i.bak \
    -e "${rev_line}s|\"$rev\"|\"$new_rev\"|" \
    -e "${hash_line}s|\"$hash\"|\"$new_hash\"|" \
    "$file"
  rm -f "$file.bak"
  say "↑ $owner/$repo: $rev → $new_rev"
  changed+=("$file")
done

if ((${#changed[@]})); then
  printf '%s\n' "${changed[@]}" | sort -u
fi
exit "$failed"
