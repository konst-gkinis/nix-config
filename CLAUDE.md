# nixos-config

nix-darwin config for macOS, user `kg`, home `/Users/kg`.

## Structure
- `darwin/default.nix` — system config, Homebrew, home-manager wiring
- `darwin/casks.nix` — Homebrew casks list
- `darwin/dock/` — dock config
- `shared/packages.nix` — nixpkgs system packages (shared between darwin/nixos)
- `shared/home.nix`, `darwin/home.nix` — home-manager config
- `flake.nix` — flake inputs/outputs

## Adding software
- **GUI macOS apps** → `darwin/casks.nix` (Homebrew cask, preferred for apps needing proper macOS integration/signing)
- **CLI tools / cross-platform** → `shared/packages.nix` (nixpkgs)
- Apply changes: `darwin-rebuild switch --flake .`

## Key facts
- Shell: zsh with powerlevel10k
- Homebrew casks currently: iterm2, visual-studio-code
- Nix GC: weekly, deletes >30 days
- Experimental features: nix-command, flakes
- home-manager stateVersion: 23.11

## Bootstrapping a new machine
Run this single command on a fresh macOS or NixOS machine:
```
sh <(curl -L https://raw.githubusercontent.com/konst-gkinis/nix-config/main/bootstrap.sh)
```
The script installs Nix (if missing), clones the repo to `~/.config/nix-config`, prompts for
machine-specific values (user, name, email, hostname, timezone, etc.), writes a `host.nix` in
the repo root, then runs `nix run ".#build-switch"`. The `host.nix` file is generated per-machine
and is gitignored — it must not be committed.
