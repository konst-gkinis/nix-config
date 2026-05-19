# nix-config

Declarative configuration for macOS (nix-darwin) and NixOS, sharing a single home-manager profile across both. One flake, two outputs, per-machine values injected via a gitignored `host.nix`.

## Bootstrap a new machine

```sh
sh <(curl -L https://raw.githubusercontent.com/konst-gkinis/nix-config/main/bootstrap.sh)
```

The script:

1. Detects OS and architecture.
2. Installs Xcode CLT and Nix (Determinate installer) on a fresh macOS; assumes Nix is already present on Linux.
3. Clones this repo to `~/.config/nix-config`.
4. Generates `~/.ssh/id_ed25519` if missing (used for SSH auth + git commit signing).
5. Prompts for machine settings (user, full name, email, hostname, timezone, personal-machine flag, and on Linux also the authorized SSH key and disk device).
6. Writes a `host.nix` at the repo root with those values.
7. Shows the SSH public key and pauses for you to paste it into GitHub as both an *Authentication key* and a *Signing key*.
8. Runs `nix run .#build-switch`.

`host.nix` is per-machine and gitignored — never commit it.

## Repo layout

| Path | Purpose |
|---|---|
| `flake.nix` | Inputs, outputs, and the `settings` defaults that `host.nix` overrides. |
| `bootstrap.sh` | The curl-able installer described above. |
| `host.nix` *(generated)* | Per-machine overrides. Gitignored. |
| `darwin/default.nix` | nix-darwin system config: Nix daemon, Homebrew, macOS defaults, home-manager wiring. |
| `darwin/casks.nix` | Homebrew casks installed on every Mac. |
| `darwin/casks-personal.nix` | Extra casks installed only when `isPersonal = true`. |
| `darwin/home.nix` | macOS-only home-manager bits (iTerm2 dynamic profile). |
| `darwin/dock/` | macOS Dock layout module. |
| `nixos/default.nix` | NixOS system config: boot, networking, X11/bspwm, services. |
| `nixos/disk-config.nix` | disko partition layout (uses `diskDevice` from `host.nix`). |
| `nixos/home.nix` | NixOS-only home-manager bits (polybar, dunst, gtk theme). |
| `nixos/packages.nix` | NixOS-only system packages. |
| `shared/home.nix` | Cross-platform home-manager config: shell, git, vim, alacritty, tmux, ssh. |
| `shared/packages.nix` | Cross-platform system packages (CLI tools). |
| `shared/nixpkgs.nix` | `nixpkgs.config` (unfree, etc.). |
| `apps/<system>/` | Flake apps: `build-switch`, `apply`, `clean`, etc. |
| `overlays/` | nixpkgs overlays (custom fonts, etc.). |
| `config/` | Static config files (p10k, polybar themes, login wallpaper). |
| `claude/` | Claude Code static config (`settings.json`, `statusline-command.sh`), symlinked into `~/.claude/`. |

## Configurable values (`host.nix`)

```nix
{
  user = "kg";                       # Unix username
  name = "Konstantinos Gkinis";      # git user.name
  email = "konst.gkinis@gmail.com";  # git user.email
  isPersonal = true;                 # adds casks-personal.nix on darwin
  hostName = "nixos";                # NixOS hostname
  timeZone = "America/New_York";
  sshKeys = [ "ssh-ed25519 AAAA..." ];  # NixOS authorized_keys
  diskDevice = "/dev/nvme0n1";          # NixOS disko target
}
```

Any key omitted falls back to the default defined in `flake.nix`.

## Adding software

- **CLI tools / cross-platform** → `shared/packages.nix` (nixpkgs).
- **GUI macOS apps** → `darwin/casks.nix` (Homebrew cask). Use `darwin/casks-personal.nix` for apps you only want on personal machines.
- **NixOS-only packages** → `nixos/packages.nix`.
- **User-level programs with config** (e.g. shell plugins, editor settings) → `shared/home.nix` or the per-OS `home.nix`.

Apply after editing:

```sh
nix run .#build-switch
```

(Or `darwin-rebuild switch --flake .` / `sudo nixos-rebuild switch --flake .` directly.)

## Commit signing

`programs.git.signing` is configured to sign commits and tags by default using your SSH key at `~/.ssh/id_ed25519.pub` (`gpg.format = ssh`). The bootstrap script generates that key per machine and prompts you to register it on GitHub as a signing key. Each machine has its own key — revoke one without affecting the others.

For local verification (so `git log --show-signature` and `git verify-commit` work offline), the bootstrap script also runs `scripts/setup-signature-verification.sh`, which writes `~/.config/git/allowed_signers` and points `gpg.ssh.allowedSignersFile` at it. Re-run it manually if you ever rotate the key.

## Claude Code config

Static files under `claude/` are symlinked into `~/.claude/` by home-manager. To change them, edit the files in this repo and run `nix run .#build-switch`. The symlinks point into the nix store and are read-only — Claude's dynamic state (`projects/*/memory/`, sessions, history) is left untouched and is not synced by this repo.

## Key facts

- Shell: zsh with powerlevel10k.
- Nix: lix (darwin), upstream nix (NixOS), with `nix-command` and `flakes` enabled.
- Nix GC: weekly, deletes generations older than 1 day.
- home-manager `stateVersion`: 23.11 (darwin), 25.11 (NixOS).
- Substituters: `cache.nixos.org`, `nix-community.cachix.org`.
