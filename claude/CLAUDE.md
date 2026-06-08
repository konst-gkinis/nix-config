# Nix Environment Guidelines

This system is managed by Nix — either nix-darwin (macOS) or NixOS (Linux).

## Package management

For one-off tool use, prefer ephemeral installs that don't persist:
- `nix run nixpkgs#<package>` — run without installing
- `ns <package>` — open a temporary shell with the package (wraps `nix shell nixpkgs#...`, keeps zsh + prompt active)
- `brew install <package>` is also acceptable for ephemeral use on macOS

Do NOT use global installs that persist outside Nix:
- No `npm install -g`, `pip install`, `uv tool install`, `cargo install`

To add a tool **permanently**, edit the Nix config at `~/nixos-config`:
- CLI tools → `~/nixos-config/shared/packages.nix` (nixpkgs)
- macOS GUI apps → `~/nixos-config/darwin/casks.nix` (Homebrew cask)
- Then apply with `nix run .#build-switch` from `~/nixos-config`
