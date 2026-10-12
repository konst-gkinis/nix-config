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

# nix shortcuts
shell() {
    nix-shell '<nixpkgs>' -A "$1"
}

# Apply the config, then replace this shell with a fresh one so it
# picks up the new .zshrc. A function, not an alias: build-switch runs
# in a child process and cannot exec the shell that started it.
nbs() {
  nix run .#build-switch -- "$@" && exec zsh
}

# Update flake inputs, commit if flake.lock changed, then build-switch.
# Idempotent: no-ops if flake.lock is already up to date.
nup() {
  local nixos_dir="$NH_FLAKE"
  (cd "$nixos_dir" && nix flake update || return 1)
  git -C "$nixos_dir" diff --quiet flake.lock && return 0
  git -C "$nixos_dir" add flake.lock && \
  git -C "$nixos_dir" commit -m "chore: update flake inputs" && \
  (cd "$nixos_dir" && nix run .#build-switch) && exec zsh
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
