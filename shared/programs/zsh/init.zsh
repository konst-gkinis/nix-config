if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi

# Force a valid UNIX locale (macOS region en_DK has no UNIX locale,
# which makes iTerm2 and CLI tools complain)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Define variables for directories
export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
export PATH=$HOME/.local/share/bin:$PATH

# Remove history data we don't want to see
export HISTIGNORE="pwd:ls:cd"

# Apply the config, then replace this shell with a fresh one so it
# picks up the new .zshrc. A function, not an alias: build-switch runs
# in a child process and cannot exec the shell that started it.
nbs() {
  nix run .#build-switch -- "$@" && exec zsh
}

# Update flake inputs, commit if anything changed, then build-switch.
# --pins (-p) also bumps the fetchFromGitHub pins marked
# "# nup --pins: follow ..." (scripts/update-pins.sh). Commits only the
# files it changed. Idempotent: no-ops if nothing changed.
nup() {
  emulate -L zsh
  local nixos_dir="$NH_FLAKE" pins=false out
  local msg="chore: update flake inputs"
  case ${1-} in
    --pins | -p) pins=true; msg="chore: update flake inputs and pinned sources" ;;
    "") ;;
    *) print -u2 "usage: nup [--pins]"; return 2 ;;
  esac
  local -a files=(flake.lock)
  if $pins; then
    # Before the flake update: the script refuses dirty files, and a
    # refusal should leave flake.lock untouched too.
    out=$("$nixos_dir/scripts/update-pins.sh" "$nixos_dir") || return 1
    files+=(${(f)out})
  fi
  (cd "$nixos_dir" && nix flake update) || return 1
  git -C "$nixos_dir" diff --quiet -- $files && return 0
  git -C "$nixos_dir" add -- $files &&
    git -C "$nixos_dir" commit -m "$msg" -- $files &&
    (cd "$nixos_dir" && nix run .#build-switch) && exec zsh
}

# Show which packages `nup` would update, without building or touching
# flake.lock. nh can't do this: its diff needs both closures built. Instead
# evaluate the package list twice — pinned lock vs. latest inputs
# (--recreate-lock-file --no-write-lock-file) — and diff the names, which
# carry the versions. Covers systemPackages + home.packages only; tools
# pulled in by a home-manager `programs.<x>.enable` module aren't listed.
ncheck() {
  emulate -L zsh
  local arch=${$(uname -m)/arm64/aarch64} cfg
  if [[ $OSTYPE == darwin* ]]; then
    cfg="darwinConfigurations.$arch-darwin"
  elif grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    cfg="nixosConfigurations.wsl"
  else
    cfg="nixosConfigurations.$arch-linux"
  fi
  local expr='c: map (p: p.name or "")
    (c.environment.systemPackages
     ++ builtins.concatMap (u: u.home.packages) (builtins.attrValues c.home-manager.users))'
  local -a list=(nix eval --json "path:$NH_FLAKE#$cfg.config" --apply "$expr")
  # Nix's stderr (dirty-tree, deprecation, "not writing lock file" warnings)
  # is shown only when an eval fails.
  setopt pipefail
  local err=$(mktemp) old new
  if ! old=$(NIXPKGS_ALLOW_UNFREE=1 "${list[@]}" 2>$err | jq -r '.[]' | sort -u) ||
     ! new=$(NIXPKGS_ALLOW_UNFREE=1 "${list[@]}" --recreate-lock-file --no-write-lock-file \
       2>$err | jq -r '.[]' | sort -u); then
    cat $err >&2; rm -f $err; return 1
  fi
  rm -f $err
  local changes
  changes=$(command diff <(print -r -- "$old") <(print -r -- "$new") | grep '^[<>]')
  if [[ -z $changes ]]; then
    print "No package updates."
    return 0
  fi
  print -r -- "$changes" | sed -e 's/^< /  - /' -e 's/^> /  + /'
}

# Temporary shell with extra packages, keeping zsh + p10k visible.
# The flakes `nix shell` doesn't set $IN_NIX_SHELL, so the p10k
# nix_shell segment never lights up (classic `nix-shell -p` does set
# it). We set it ourselves; `nix shell` inherits it into the inner
# zsh, so the segment shows. Bare names resolve to nixpkgs#<name>;
# refs containing `#` or `:` pass through (e.g. `ns nixpkgs#hello`).
ns() {
  emulate -L zsh
  local -a refs
  local p
  for p in "$@"; do
    if [[ $p == *[#:]* ]]; then refs+=("$p"); else refs+=("nixpkgs#$p"); fi
  done
  IN_NIX_SHELL=impure nix shell "${refs[@]}" --command zsh -i
}

# ripgrep rendered by delta's grep view. `rg --json` is what delta
# wants — parsing plain grep output is ambiguous when a match itself
# contains a colon. rg ignores --json for --files/-l/-c, where delta
# would render nothing and just append its "this isn't a diff" hint,
# so those bypass it, as does a non-terminal stdout (scripts, pipes,
# $(...)). `command rg` skips the wrapper entirely.
rg() {
  emulate -L zsh
  if [[ ! -t 1 ]]; then
    command rg "$@"
    return
  fi
  local a
  for a in "$@"; do
    case $a in
      --files|--files-with-matches|-l|--count|-c|--count-matches|--json|--help|-h|--version|-V)
        command rg "$@"
        return
        ;;
    esac
  done
  command rg --json "$@" | delta
  return $pipestatus[1]
}
