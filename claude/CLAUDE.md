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

# Working preferences

- When a result isn't directly observable (GUI, game, rendered output), capture it — render a screenshot, etc. — and verify before reporting success. Don't rely on logs or headless checks alone.
- Clearly separate what you verified from what needs my live or subjective judgment (movement feel, visual polish, timing). Hand those off explicitly instead of claiming they're done.
- For ambiguous or large tasks, ask clarifying questions up front — with a recommendation — before committing to an approach, rather than guessing.
- Commit work in small, logical, incremental git commits as you go (when working in a git repo).
