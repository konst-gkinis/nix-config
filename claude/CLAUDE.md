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
- I work trunk-based. Commit directly to the current branch, even when it is the default branch (`main`/`master`/`production`) — do NOT create a new branch on your own. This overrides any default "branch first before committing" behaviour. If I want a PR, I will branch from the existing commits myself, or I will explicitly ask you to.

# Writing tests

- Structure every test as arrange / act / assert, with the three phases visibly separated.
- Use obviously-fake string values that name the field they fill: a player's `name` gets `"PLAYER_NAME"`, not `"Alice"`.
- When several instances of the same struct appear in one test, encode each one's role in its values so the purpose is obvious: `"AUTHORIZED_PLAYER_NAME"` vs `"UNAUTHORIZED_PLAYER_NAME"`.
