# nixos-config

nix-darwin config for macOS, user `kg`, home `/Users/kg`.

## Structure
- `darwin/default.nix` — system config, Homebrew, home-manager wiring
- `darwin/casks.nix` — Homebrew casks list
- `darwin/dock/` — dock config
- `nixos/default.nix` — bare-metal NixOS config (X11, disko, bootloader)
- `wsl/default.nix` — NixOS-WSL config (no bootloader/X11/disko)
- `wsl/home.nix`, `wsl/packages.nix` — WSL-specific home-manager config and packages
- `shared/packages.nix` — nixpkgs packages shared across all targets
- `shared/home.nix` — home-manager programs shared across all targets
- `flake.nix` — flake inputs/outputs

## Adding software
- **GUI macOS apps** → `darwin/casks.nix` (Homebrew cask)
- **CLI tools / cross-platform** → `shared/packages.nix` (nixpkgs)
- **WSL-only packages** → `wsl/packages.nix`
- Apply on macOS: `darwin-rebuild switch --flake .`
- Apply on WSL: `sudo nixos-rebuild switch --flake .#wsl`

## NixOS-WSL setup
The `nixosConfigurations.wsl` flake target is for NixOS running under WSL2.
It uses `nixos-wsl` (github:nix-community/NixOS-WSL) and omits bootloader, disko, and X11.
`bootstrap.sh` auto-detects WSL and uses the `wsl` target.

To install NixOS-WSL on a Windows machine:
1. Download the NixOS-WSL tarball from https://github.com/nix-community/NixOS-WSL/releases
2. `wsl --import NixOS C:\NixOS nixos-wsl.tar.gz --version 2`
3. `wsl -d NixOS`
4. Run bootstrap.sh from inside the NixOS-WSL instance

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

## Gotchas
- `specialArg` for the git full name is called `fullName`, not `name`. Don't rename it
  back — home-manager's module system reserves `name` for the user key, and overriding
  it silently breaks `config.home.homeDirectory`.
