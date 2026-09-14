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

## Second git identity
`workGitDir` in the `flake.nix` defaults scopes a second GitHub account to a directory
(currently `~/workspace/portchain`; `null` emits nothing). A trailing slash is optional —
`shared/home.nix` normalises it, which matters because git treats `gitdir:~/foo` as
"a repo at exactly that path" and only `gitdir:~/foo/` as "everything beneath it".

It adds a conditional include at the end of `~/.config/git/config`, so repos under that
directory additionally read `<dir>/.gitconfig` — a plain, machine-local file holding the
work `user.name` / `user.email` / `user.signingKey`. The identity itself is deliberately
*not* in this repo and needs no rebuild to change. A missing target file is a silent
no-op, so the pointer is safe to commit and ship to machines that have no work setup.

Git has no directory-inherited config of its own (it never walks up the tree looking
for one), so the pointer has to be global — that part cannot live outside home-manager.

GitHub refuses the same public key on two accounts, so the second account also needs
its own keypair plus a `Host` alias in `~/.ssh/config_external` (included from
`shared/home.nix`) with `IdentitiesOnly yes`. For local verification of work-signed
commits, `~/.config/git/allowed_signers` needs a second line mapping the work email to
the work pubkey.

## Git config ownership
All global git config is home-manager's (`shared/home.nix` → `~/.config/git/config`,
a nix store symlink). There is deliberately **no `~/.gitconfig`**; one existed
pre-Nix and silently overrode the generated `user.*`, since git reads both and
`~/.gitconfig` last. Don't recreate it.

Consequences:
- `git config --global ...` now fails with `could not lock config file` — with
  `~/.gitconfig` absent, git targets the store symlink. That's intended: global
  config changes belong in `shared/home.nix`. Use `--local` for per-repo settings.
- Global ignores live in `programs.git.ignores` → `~/.config/git/ignore`. Don't set
  `core.excludesFile`; it would make git ignore that file entirely.
- `gpg.ssh.allowedSignersFile` is set declaratively; only the file's *contents* are
  machine-specific, written by `scripts/setup-signature-verification.sh` (which no
  longer writes the pointer).

## Gotchas
- `nix run .#build-switch` quits iTerm2 when `TERM_PROGRAM=iTerm.app`
  (`apps/aarch64-darwin/build-switch:66`), which kills any agent session running inside
  it mid-switch. Run it as `env TERM_PROGRAM=other nix run .#build-switch` to skip the
  restart.
- `programs.git.includes` must be used for the `workGitDir` override, not a hand-rolled
  `settings.includeIf`. home-manager emits `includes` with `mkAfter` so they land after
  the global `user.*`; sections in `settings` are sorted alphabetically, which would put
  `includeIf` *before* `user` and let the global identity win.
- `host.nix` is gitignored, and flake evaluation only sees git-tracked files — so
  `nix eval`/`build-switch` on a dirty tree silently ignores it until it is at least
  `git add -N`'d.
- `specialArg` for the git full name is called `fullName`, not `name`. Don't rename it
  back — home-manager's module system reserves `name` for the user key, and overriding
  it silently breaks `config.home.homeDirectory`.
