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

A test is read far more often than written, usually by someone debugging it. Make the data that differentiates the test impossible to miss; push everything else behind helpers with sensible defaults.

## Shape
- Structure every test as arrange / act / assert: three blocks separated by a blank line. Act is one line.
- Only the values the assertion depends on appear in the test; everything else is a default. A reader should tell what the test is about from Arrange alone. After builders exist, Arrange is 1–3 statements — if longer, the test covers several behaviours, a scenario builder is missing, or the production API needs too much ceremony (raise that as a design finding).
- Use obviously-fake string values that name the field they fill: a player's `name` gets `"PLAYER_NAME"`, not `"Alice"`.
- When several instances of the same struct appear in one test, encode each one's role in its values: `"AUTHORIZED_PLAYER_NAME"` vs `"UNAUTHORIZED_PLAYER_NAME"`.
- Name the test after the behaviour, since the name is what a CI failure shows. A plain name like "returns a terminal call" is right only for a genuine happy-path / golden-master test.

## Builders (setup and expected objects)
- Extract setup into a builder that returns a complete, valid, type-checked object and takes partial overrides (`buildTerminalCall({ berthId: null })`). Prefer this over casts (`as unknown as T`, `mock<T>()`), which go stale silently.
- Don't parametrise what the test doesn't care about — a parameter claims the value matters. When nothing differentiates the test, pass nothing.
- Name builders as noun phrases (`buildUser`, `buildPendingInvoice`). Defaults are valid and boring; don't default to `0`/`null`/`""` unless genuinely neutral.
- Never let a default satisfy an assertion: if the test asserts `status === "omitted"`, it sets `status` itself. Randomise identity fields (ids, unique names) only, never asserted fields.
- Return a fresh object on every call; never share a mutable fixture across tests. No mystery guests: values the test depends on don't live in a distant fixture or `beforeEach`.
- Nest builders for nested graphs and deep-merge overrides (don't shallow-spread away nested defaults). Extract a named domain scenario (`buildOmittedTerminalCall`) when a combination recurs; no builders-for-builders. Small value objects don't need one.
- A builder is a pure data constructor: no logic, validation, persistence or mock/stub setup. Persist as a separate visible step: `seed(buildX({...}))`.
- Builders live in test-only files, never in production code; never add test-only constructors/fields to production types.
- Large expected objects get a builder too, following the same rule: `expect(body).toEqual(expectedResponse({ status: "omitted" }))`. One or two values inline is fine.
- When changing a builder default breaks tests, those tests were secretly relying on it — fix them, don't restore the default.

## Expectations
- Pin expectations as literals rather than re-deriving them from the seed data the code under test reads. Where the expectation genuinely depends on a generated value (db id, timestamp), pass it explicitly into the expected-object builder.
- A golden-master test states its contract in a docblock: it asserts the output does not change, not that it is correct, and intentional changes must update the expected body in the same commit.
- Keep tests deterministic and independent of each other.
