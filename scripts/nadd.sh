#!/usr/bin/env bash
# halp: [--cask|--nix] [--login] [--switch] [-v] <name|github-url> — add a nixpkgs package or Homebrew cask to this config
# Resolve a name or GitHub link to a nixpkgs attribute (shared/packages.nix) or a Homebrew
# cask (darwin/casks.nix) and append it there. Packaged in shared/packages.nix as `nadd`.
#
#   nadd ripgrep                         exact nixpkgs attr       -> shared/packages.nix
#   nadd rectangle --login               exact cask, start at login -> darwin/casks.nix
#   nadd https://github.com/owner/repo   matched by the package's homepage / source / download URL
#   nadd ripgerp                         no exact match: pick from fuzzy suggestions (fzf)
#   nadd crmne/tap/spotifast             a cask from a third-party tap (GitHub crmne/homebrew-tap)
#
# A cask that isn't in the official list is looked for in third-party taps: for a GitHub link
# in <owner>/homebrew-tap, else by GitHub code search (needs gh, logged in). Picking one also
# declares its tap as a `tap-*` flake input and locks it, since nix-homebrew's taps are immutable.
#
# --verbose (-v) also prints Nix's own warnings, the diff of the edited file and the apply hint.
# nixpkgs is the revision locked in flake.lock, so whatever is picked builds with this config.
# Both lists are cached in ~/.cache/nadd (nixpkgs per revision, casks for a day).
# A name that is both a package and a cask asks which one; --nix / --cask skip the question.
set -euo pipefail

usage() {
  sed -n 's/^# halp: /nadd /p' "$0" 2>/dev/null || true
  echo "usage: nadd [--cask|--nix] [--login] [--switch] [-v|--verbose] <name|github-url>" >&2
  exit 2
}

only="" login=0 switch=0 verbose=0 query=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cask) only=cask ;;
    --nix) only=nix ;;
    --login) login=1 ;;
    --switch) switch=1 ;;
    -v | --verbose) verbose=1 ;;
    -h | --help) usage ;;
    -*) echo "nadd: unknown option $1" >&2; usage ;;
    *) [ -z "$query" ] || usage; query=$1 ;;
  esac
  shift
done
[ -n "$query" ] || usage

flake=${NADD_FLAKE:-${NH_FLAKE:?NH_FLAKE is not set (it points at the nix-config checkout)}}
pkgs_file=$flake/shared/packages.nix
casks_file=$flake/darwin/casks.nix
cache=${XDG_CACHE_HOME:-$HOME/.cache}/nadd
mkdir -p "$cache"

[ "$(uname -s)" = Darwin ] || { [ "$only" != cask ] || { echo "nadd: casks are macOS only" >&2; exit 1; }; only=nix; }
tap_re='^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.@+-]+)$' # owner/tap/token
if [[ $query =~ $tap_re ]]; then
  [ "$only" != nix ] || { echo "nadd: $query is a Homebrew tap cask" >&2; exit 1; }
  only=cask
fi
[ "$login" = 0 ] || [ "$only" != nix ] || { echo "nadd: --login only applies to casks" >&2; exit 1; }

say() { printf '%s\n' "$*" >&2; }
# Nix's own stderr (e.g. "Nix search path entry … does not exist") only with --verbose.
nix_err=/dev/null
[ "$verbose" = 0 ] || nix_err=/dev/stderr

# Emphasis only on a terminal, and not with NO_COLOR set.
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then em=$'\e[1;36m' off=$'\e[0m'; else em="" off=""; fi
# Wrap to the terminal width, indenting continuation lines by two spaces.
wrap() {
  local w
  w=$(tput cols 2>/dev/null </dev/tty || echo 80)
  fold -s -w "$((w > 20 ? w - 2 : 78))" | sed -e 's/ *$//' -e '1!s/^/  /'
}

# --- data sources -------------------------------------------------------------------------

rev=$(jq -r '.nodes.nixpkgs.locked.rev' "$flake/flake.lock")
nixpkgs="github:nixos/nixpkgs/$rev"
system=$(nix eval --impure --raw --expr builtins.currentSystem 2>"$nix_err")

# TSV: attr \t version \t description
nix_list() {
  local f=$cache/nixpkgs-$rev-$system.tsv
  if [ ! -s "$f" ]; then
    say "Indexing nixpkgs ${rev:0:7} (once per revision, ~1 min)…"
    nix search "$nixpkgs" '^' --json 2>/dev/null |
      jq -r --arg p "legacyPackages.$system." \
        'to_entries[] | [(.key | ltrimstr($p)), .value.version, (.value.description // "" | gsub("[\t\n]"; " "))] | @tsv' \
        >"$f.tmp"
    mv "$f.tmp" "$f"
  fi
  cat "$f"
}

cask_json() {
  local f=$cache/cask.json
  if [ ! -s "$f" ] || [ -n "$(find "$f" -mtime +0)" ]; then
    say "Fetching the Homebrew cask list…"
    curl -fsSL --compressed -o "$f.tmp" https://formulae.brew.sh/api/cask.json
    mv "$f.tmp" "$f"
  fi
  printf '%s\n' "$f"
}

# TSV: token \t version \t description (+ display name)
cask_list() {
  jq -r '.[] | [.token, .version, ((.desc // "") + " (" + (.name | join(", ")) + ")" | gsub("[\t\n]"; " "))] | @tsv' "$(cask_json)"
}

lower() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

# Third-party taps. A cask from one is "<owner>/<tap>/<token>": file Casks/[<letter>/]<token>.rb
# in the GitHub repo <owner>/homebrew-<tap>. The .rb is cached for a day.
tap_rb() { # owner tap token [path in repo] -> path of the cached .rb; fails if there is none
  local f=$cache/taps/$1/$2/$3.rb p
  if [ ! -s "$f" ] || [ -n "$(find "$f" -mtime +0)" ]; then
    mkdir -p "${f%/*}"
    for p in ${4:+"$4"} "Casks/$3.rb" "Casks/${3:0:1}/$3.rb"; do
      if curl -fsSL "https://raw.githubusercontent.com/$1/homebrew-$2/HEAD/$p" -o "$f.tmp" 2>/dev/null; then
        mv "$f.tmp" "$f"
        break
      fi
    done
    rm -f "$f.tmp"
  fi
  [ -s "$f" ] && printf '%s\n' "$f"
}

rb_field() { sed -n "s/^  $1 \"\\(.*\\)\".*/\\1/p" "$2" | head -n 1; } # field file -> its first string value

# Adds a tap cask's candidate line to $all (so expand() shows it) and prints its key.
tap_candidate() { # owner tap token [path in repo] -> "cask\t<id>"
  local f id=$1/$2/$3
  f=$(tap_rb "$@") || return 1
  grep -qF "cask"$'\t'"$id"$'\t' "$all" ||
    printf 'cask\t%s\t%s\t%s (%s)\n' "$id" "$(rb_field version "$f")" "$(rb_field desc "$f")" "$(rb_field name "$f")" >>"$all"
  printf 'cask\t%s\n' "$id"
}

# GitHub code search over Casks/*.rb in homebrew-* repos. Needs gh, logged in.
tap_search() { # search terms -> "cask\t<id>" keys
  local hits full path tap token
  command -v gh >/dev/null || return 0
  hits=$(gh api -X GET search/code -f q="$1 path:Casks language:Ruby" \
    --jq '.items[] | [.repository.full_name, .path] | @tsv' 2>"$nix_err") || return 0
  while IFS=$'\t' read -r full path; do
    full=$(lower "$full") tap=${full#*/} token=${path##*/}
    [[ $tap == homebrew-* && $full != homebrew/homebrew-cask && $token == *.rb ]] || continue
    tap_candidate "${full%%/*}" "${tap#homebrew-}" "${token%.rb}" "$path" || true
  done <<<"$hits"
}

# Candidate lines are "<kind>\t<id>\t<version>\t<description>".
candidates() {
  [ "$only" = cask ] || nix_list | sed 's/^/nix\t/'
  [ "$only" = nix ] || cask_list | sed 's/^/cask\t/'
}

# --- matching -----------------------------------------------------------------------------

all=$(mktemp)
trap 'rm -f "$all"' EXIT
candidates >"$all"

matches="" slug="" explicit_tap=0
if [[ $query =~ github\.com[/:]([^/]+)/([^/#?]+) ]]; then
  owner=$(lower "${BASH_REMATCH[1]}")
  repo=${BASH_REMATCH[2]%.git}
  slug=$(lower "$owner/$repo")
  say "Looking for packages built from github.com/$slug…"
  name=$repo

  if [ "$only" != nix ]; then
    matches+=$(jq -r --arg s "$slug" '
      .[] | select([.homepage, .url] | map(. // "" | ascii_downcase)
                   | any(test("github\\.com/" + $s + "(\\.git)?([/#?]|$)")))
          | .token' "$(cask_json)" | sed 's/^/cask\t/')$'\n'
  fi

  if [ "$only" != cask ]; then
    # Homepages aren't in the search index, so evaluate them for the attrs named like the repo.
    lrepo=$(tr '[:upper:]' '[:lower:]' <<<"$repo")
    attrs=$(awk -F'\t' -v r="$lrepo" '$1 == "nix" {
        a = tolower($2); n = split(a, seg, "."); if (index(seg[n], r) || index(r, seg[n]) && length(seg[n]) > 2) print $2
      }' "$all" | head -n 200 | jq -Rsc 'split("\n") | map(select(. != ""))')
    matches+=$(nix eval --json --impure --expr "
      let
        p = (builtins.getFlake \"$nixpkgs\").legacyPackages.$system;
        lib = (builtins.getFlake \"$nixpkgs\").lib;
        urls = a: let
            d = lib.attrByPath (lib.splitString \".\" a) null p;
            t = builtins.tryEval (builtins.toJSON [
              (d.meta.homepage or \"\") (d.src.meta.homepage or \"\") (d.src.url or \"\") (d.src.urls or [ ])
            ]);
          in if t.success then t.value else \"\";
      in map (a: { inherit a; u = urls a; }) (builtins.fromJSON ''$attrs'')
    " 2>/dev/null | jq -r --arg s "$slug" '
      .[] | select(.u | ascii_downcase | test("github\\.com/" + $s + "(\\.git)?([/#?\"]|$)")) | "nix\t" + .a')$'\n'
  fi
elif [[ $query =~ $tap_re ]]; then
  explicit_tap=1
  owner=$(lower "${BASH_REMATCH[1]}") tap=$(lower "${BASH_REMATCH[2]}") name=${BASH_REMATCH[3]}
  tap=${tap#homebrew-}
  matches=$(tap_candidate "$owner" "$tap" "$name") ||
    { say "nadd: no cask $name in github.com/$owner/homebrew-$tap"; exit 1; }
else
  name=$query
  matches=$(awk -F'\t' -v q="$query" '$2 == q { print $1 "\t" $2 }' "$all")
fi
matches=$(grep -v '^$' <<<"$matches" || true)

# Not an official cask: look in third-party taps. That costs network round trips, so only
# when nothing matched at all, or --cask asked for a cask and none matched.
if [ "$explicit_tap" = 0 ] && [ "$only" != nix ] && ! grep -q '^cask' <<<"$matches" &&
  { [ "$only" = cask ] || [ -z "$matches" ]; }; then
  say "Not an official cask; searching third-party Homebrew taps…"
  taps=""
  if [ -n "$slug" ]; then
    # The usual home is <owner>/homebrew-tap; otherwise any cask downloading from the repo.
    taps=$(tap_candidate "$owner" tap "$(lower "$repo")" || tap_search "\"github.com/$slug\"")
  else
    taps=$(tap_search "filename:$query.rb")
  fi
  if [ -n "$taps" ]; then
    matches=$(printf '%s\n%s\n' "$matches" "$taps" | grep -v '^$' | awk '!seen[$0]++')
  else
    command -v gh >/dev/null && gh auth status >/dev/null 2>&1 ||
      say "(searching taps by name needs gh, logged in)"
    say "None found; a tap cask can also be given as <owner>/<tap>/<name>."
  fi
fi
# A repo that moved (owner renamed) no longer matches by URL; fall back to its name.
if [ -z "$matches" ] && [ "$name" != "$query" ]; then
  matches=$(awk -F'\t' -v q="$(tr '[:upper:]' '[:lower:]' <<<"$name")" 'tolower($2) == q { print $1 "\t" $2 }' "$all")
fi

# Show full candidate lines for "<kind>\t<id>" keys, in that order.
expand() { awk -F'\t' 'NR == FNR { want[$1 "\t" $2] = 1; next } want[$1 "\t" $2]' - "$all"; }

# Fuzzy suggestions: substring hits first, then near-misses (typos) by edit similarity.
suggest() {
  python3 -I - "$1" "$all" <<'PY'
import difflib, sys
q, path = sys.argv[1].lower(), sys.argv[2]
rows = [l.rstrip("\n").split("\t") for l in open(path, encoding="utf-8")]
names = {}
for r in rows:
    names.setdefault(r[1].split(".")[-1].lower(), []).append(r)
sub = sorted((n for n in names if q in n), key=lambda n: (len(n), n))[:15]
close = difflib.get_close_matches(q, list(names), n=15, cutoff=0.6)
seen = []
for n in sub + close:
    if n not in seen:
        seen.append(n)
for n in seen:
    for r in names[n]:
        print("\t".join(r))
PY
}

pick() { # $1 prompt, stdin candidate lines -> one line on stdout
  if [ -t 2 ]; then
    fzf --prompt="$1> " --height=50% --reverse --delimiter='\t' --no-sort || exit 130
  else
    say "Not interactive; candidates:"
    column -t -s $'\t' >&2
    exit 1
  fi
}

n=$(grep -c . <<<"$matches" || true)
if [ "$n" = 1 ]; then
  chosen=$(expand <<<"$matches")
elif [ "$n" -gt 1 ]; then
  say "\"$query\" matches more than one source — pick one (or rerun with --nix / --cask):"
  chosen=$(expand <<<"$matches" | pick "$name")
else
  sugg=$(suggest "$name")
  [ -n "$sugg" ] || { say "nadd: nothing like \"$name\" found"; exit 1; }
  say "No exact match for \"$query\"; did you mean:"
  chosen=$(pick "$name" <<<"$sugg")
fi
[ -n "$chosen" ] || exit 1
IFS=$'\t' read -r kind id version desc <<<"$chosen"
line=$(printf '%s %s %s — %s\n' "$kind" "$id" "$version" "$desc" | wrap)
printf '%s\n' "${line/#"$kind $id"/"$kind $em$id$off"}" >&2

# --- editing ------------------------------------------------------------------------------

nix_ref() { # attr path -> Nix expression valid inside `with pkgs; [ ... ]`
  local out="" seg first=1
  IFS=. read -ra segs <<<"$1"
  for seg in "${segs[@]}"; do
    if [[ $seg =~ ^[A-Za-z_][A-Za-z0-9_\'-]*$ ]]; then q=$seg; else q="\"$seg\""; fi
    if [ $first = 1 ]; then
      [[ $q == \"* ]] && out="pkgs.$q" || out=$q
      first=0
    else
      out+=".$q"
    fi
  done
  printf '%s\n' "$out"
}

# Insert lines before the last line of the file that is exactly "]".
insert_before_close() { # $1 file, stdin lines
  local f=$1 add tmp
  add=$(mktemp)
  tmp=$(mktemp)
  cat >"$add"
  awk 'NR == FNR { add = add $0 "\n"; next } { l[++n] = $0 } $0 == "]" { last = n }
    END { if (!last) exit 1; for (i = 1; i <= n; i++) { if (i == last) printf "%s", add; print l[i] } }' \
    "$add" "$f" >"$tmp" || { rm -f "$add" "$tmp"; say "nadd: no closing ] in $f"; exit 1; }
  cat "$tmp" >"$f"
  rm -f "$add" "$tmp"
}

# nix-homebrew's taps are immutable, so a tap is a flake input: flake.nix turns every `tap-*`
# input into one. Declares github:<owner>/homebrew-<tap> unless present, and locks it.
tap_added=""
ensure_tap() { # owner tap
  local url="github:$1/homebrew-$2" input backup
  grep -qiF "\"$url\"" "$flake/flake.nix" && return 0
  input=tap-$(tr -c 'A-Za-z0-9_\n-' '-' <<<"$1-$2")
  backup=$(mktemp)
  cp "$flake/flake.nix" "$backup"
  awk -v i="$input" -v u="$url" '
    $0 == "  inputs = {" { ins = 1 }
    ins && $0 == "  };" { printf "    %s = {\n      url = \"%s\";\n      flake = false;\n    };\n", i, u; ins = 0 }
    { print }' "$backup" >"$flake/flake.nix"
  if ! grep -qF "\"$url\"" "$flake/flake.nix"; then
    cp "$backup" "$flake/flake.nix"
    rm -f "$backup"
    say "nadd: no \"  inputs = {\" block in flake.nix to add the tap to"
    exit 1
  fi
  say "Locking the $1/$2 tap…"
  if ! nix flake lock "$flake" 2>"$nix_err"; then
    cp "$backup" "$flake/flake.nix"
    rm -f "$backup"
    say "nadd: couldn't lock $url (rerun with -v for Nix's error)"
    exit 1
  fi
  rm -f "$backup"
  tap_added="$1/$2" files+=" flake.nix flake.lock"
}

if [ "$kind" = nix ]; then
  [ "$login" = 0 ] || { say "nadd: --login only applies to casks"; exit 1; }
  ref=$(nix_ref "$id")
  if awk -v r="$ref" '$1 == r { found = 1 } END { exit !found }' "$pkgs_file"; then
    say "$id is already in shared/packages.nix"; exit 0
  fi
  # home-manager modules (programs.<name> = { … }) install their package themselves.
  if hm=$(grep -rlE "^[[:space:]]*(programs\.)?${id//./\\.}(\.enable)? = " \
    "$flake/shared/programs" "$flake/darwin/programs" 2>/dev/null | head -n 1) && [ -n "$hm" ]; then
    say "$id is already installed through home-manager (programs.$id in ${hm#"$flake"/})"; exit 0
  fi
  insert_before_close "$pkgs_file" <<<"  $ref"
  files=shared/packages.nix added="Added to ${em}nix shared${off} packages"
else
  if grep -Fq "\"$id\"" "$casks_file"; then
    say "$id is already in darwin/casks.nix"; exit 0
  fi
  rb="" files=darwin/casks.nix
  [[ $id =~ $tap_re ]] && tap_parts=("${BASH_REMATCH[@]:1}") || tap_parts=()
  [ ${#tap_parts[@]} = 0 ] || rb=$(tap_rb "${tap_parts[@]}")
  if [ "$login" = 1 ]; then
    if [ -n "$rb" ]; then
      app=$(rb_field app "$rb")
    else
      app=$(jq -r --arg t "$id" '.[] | select(.token == $t) | [.artifacts[] | .app? // empty | .[] | strings][0] // empty' "$(cask_json)")
    fi
    [ -n "$app" ] || { say "nadd: $id installs no .app, so it can't be a login item"; exit 1; }
  fi
  # Only once nothing else can fail, so a refused cask doesn't leave a tap behind.
  [ ${#tap_parts[@]} = 0 ] || ensure_tap "${tap_parts[0]}" "${tap_parts[1]}"
  if [ "$login" = 1 ]; then
    insert_before_close "$casks_file" <<EOF
  {
    name = "$id";
    loginItem = "${app%.app}";
  }
EOF
  else
    insert_before_close "$casks_file" <<<"  \"$id\""
  fi
  added="Added to ${em}casks${off}"
  [ "$login" = 0 ] || added+=" (starts at login)"
  [ -z "$tap_added" ] || added+=", with its tap $tap_added"
fi

say "$added"
if [ "$verbose" = 1 ]; then
  # shellcheck disable=SC2086 # $files is a space-separated list
  git -C "$flake" --no-pager diff --color=auto -U1 -- $files >&2 || true
fi

if [ "$switch" = 1 ]; then
  cd "$flake" && nix run .#build-switch
elif [ "$verbose" = 1 ]; then
  say "Apply with: (cd \"$flake\" && nix run .#build-switch)   — or rerun with --switch"
fi
