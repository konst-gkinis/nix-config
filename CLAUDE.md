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
