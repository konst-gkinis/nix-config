#!/bin/sh
# Bootstrap script for nix-config
# Usage: sh <(curl -L https://raw.githubusercontent.com/konst-gkinis/nix-config/main/bootstrap.sh)
#
# Supports: macOS (fresh or existing), NixOS (existing system only).
# NOTE: Fresh NixOS installs (disko + nixos-install) are out of scope.
#       This script only calls `nix run ".#build-switch"` which runs
#       nixos-rebuild switch — suitable for an already-bootstrapped NixOS system.

set -e

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

REPO_URL="https://github.com/konst-gkinis/nix-config"
REPO_DIR="${HOME}/.config/nix-config"

# Helper: prompt with a default value
# Usage: result=$(ask "Prompt text" "default value")
ask() {
  _prompt="$1"
  _default="$2"
  printf "%b%s [%s]: %b" "$YELLOW" "$_prompt" "$_default" "$NC" >&2
  read -r _answer
  if [ -z "$_answer" ]; then
    printf "%s" "$_default"
  else
    printf "%s" "$_answer"
  fi
}

# Helper: escape double-quotes for Nix string literals
nix_escape() {
  printf "%s" "$1" | sed 's/"/\\"/g'
}

# ── OS / Arch detection ──────────────────────────────────────────────────────

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64)  ARCH="x86_64" ;;
  arm64|aarch64) ARCH="aarch64" ;;
  *)
    printf "%bUnsupported architecture: %s%b\n" "$RED" "$ARCH" "$NC"
    exit 1
    ;;
esac

IS_WSL=0
if [ "$OS" = "Linux" ]; then
  if grep -qi microsoft /proc/version 2>/dev/null || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    IS_WSL=1
  fi
fi

case "$OS" in
  Darwin) FLAKE_SYSTEM="${ARCH}-darwin" ;;
  Linux)
    if [ "$IS_WSL" = "1" ]; then
      FLAKE_SYSTEM="wsl"
    else
      FLAKE_SYSTEM="${ARCH}-linux"
    fi
    ;;
  *)
    printf "%bUnsupported OS: %s%b\n" "$RED" "$OS" "$NC"
    exit 1
    ;;
esac

printf "%b==> Detected: %s / %s (flake system: %s)%b\n" "$GREEN" "$OS" "$ARCH" "$FLAKE_SYSTEM" "$NC"

# ── Prerequisites ────────────────────────────────────────────────────────────

printf "%b==> Checking prerequisites...%b\n" "$GREEN" "$NC"

if [ "$OS" = "Darwin" ]; then
  # Ensure Xcode Command Line Tools
  if ! xcode-select -p > /dev/null 2>&1; then
    printf "%bXcode Command Line Tools not found. Launching installer...%b\n" "$YELLOW" "$NC"
    xcode-select --install
    printf "%bPlease re-run this script after the Xcode CLT installation finishes.%b\n" "$RED" "$NC"
    exit 0
  fi

  # Ensure Nix
  if ! command -v nix > /dev/null 2>&1; then
    printf "%bNix not found. Installing via Determinate Systems installer...%b\n" "$YELLOW" "$NC"
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm
    # Source nix into current shell session
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
else
  # Linux / NixOS installer — nix is already present.
  # Ensure git is available (use nix-shell wrapper if needed).
  if ! command -v git > /dev/null 2>&1; then
    printf "%bgit not found; will use nix-shell -p git for clone...%b\n" "$YELLOW" "$NC"
    GIT="nix-shell -p git --run git"
  fi
fi

GIT="${GIT:-git}"

# ── Clone / locate repo ──────────────────────────────────────────────────────

printf "%b==> Preparing repository...%b\n" "$GREEN" "$NC"

if [ -f "${REPO_DIR}/flake.nix" ]; then
  printf "Repository already exists at %s — skipping clone.\n" "$REPO_DIR"
else
  mkdir -p "$(dirname "$REPO_DIR")"
  if [ "$GIT" = "git" ]; then
    git clone "$REPO_URL" "$REPO_DIR"
  else
    nix-shell -p git --run "git clone '$REPO_URL' '$REPO_DIR'"
  fi
fi

cd "$REPO_DIR"

# ── Collect user answers ─────────────────────────────────────────────────────

printf "%b==> Gathering machine settings (press Enter to keep default)...%b\n" "$GREEN" "$NC"

# Username
DEFAULT_USER="${USER:-$(id -un)}"
CFG_USER="$(ask "Username" "$DEFAULT_USER")"

# Full name
CFG_NAME="$(ask "Full name" "Konstantinos Gkinis")"

# Email
CFG_EMAIL="$(ask "Git email" "konst.gkinis@gmail.com")"

# Personal machine?
printf "%b%s [Y/n]: %b" "$YELLOW" "Personal machine?" "$NC" >&2
read -r _personal_ans
case "$_personal_ans" in
  n|N) CFG_IS_PERSONAL="false" ;;
  *)   CFG_IS_PERSONAL="true"  ;;
esac

# Hostname
if [ "$OS" = "Darwin" ]; then
  DEFAULT_HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname)"
else
  DEFAULT_HOSTNAME="nixos"
fi
CFG_HOSTNAME="$(ask "Hostname" "$DEFAULT_HOSTNAME")"

# Timezone
DEFAULT_TZ="$(readlink /etc/localtime 2>/dev/null | sed 's#.*/zoneinfo/##' || true)"
if [ -z "$DEFAULT_TZ" ]; then
  DEFAULT_TZ="America/New_York"
fi
CFG_TIMEZONE="$(ask "Timezone" "$DEFAULT_TZ")"

# ── Ensure a per-machine SSH key exists ──────────────────────────────────────
# Used for both SSH auth and git commit signing (gpg.format = ssh).

SSH_KEY_PATH="${HOME}/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY_PATH" ]; then
  printf "%b==> No SSH key at %s — generating ed25519 keypair...%b\n" "$GREEN" "$SSH_KEY_PATH" "$NC"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  printf "%bProtect the private key with a passphrase? [Y/n]: %b" "$YELLOW" "$NC"
  read -r _pass_ans
  case "$_pass_ans" in
    n|N)
      ssh-keygen -t ed25519 -C "$CFG_EMAIL" -N "" -f "$SSH_KEY_PATH"
      ;;
    *)
      # ssh-keygen will prompt twice for the passphrase
      ssh-keygen -t ed25519 -C "$CFG_EMAIL" -f "$SSH_KEY_PATH"
      ;;
  esac
  if [ "$OS" = "Darwin" ]; then
    # Store passphrase in macOS Keychain so signing/auth is friction-free
    ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null || true
  fi
else
  printf "%b==> Reusing existing SSH key at %s%b\n" "$GREEN" "$SSH_KEY_PATH" "$NC"
fi
SSH_PUBKEY="$(cat "${SSH_KEY_PATH}.pub")"

# SSH keys and disk device — Linux only
if [ "$OS" = "Linux" ]; then
  # SSH authorized public key
  DEFAULT_SSH_KEY=""
  if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
    DEFAULT_SSH_KEY="$(cat "${HOME}/.ssh/id_ed25519.pub")"
  fi
  if [ -z "$DEFAULT_SSH_KEY" ]; then
    DEFAULT_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOk8iAnIaa1deoc7jw8YACPNVka1ZFJxhnU4G74TmS+p"
  fi
  CFG_SSH_KEY="$(ask "SSH authorized public key" "$DEFAULT_SSH_KEY")"

  # Disk device
  printf "%bAvailable block devices:%b\n" "$YELLOW" "$NC"
  lsblk -dpno NAME,SIZE,MODEL 2>/dev/null || true
  CFG_DISK="$(ask "Disk device" "/dev/nvme0n1")"
else
  # macOS — use defaults from flake settings
  CFG_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOk8iAnIaa1deoc7jw8YACPNVka1ZFJxhnU4G74TmS+p"
  CFG_DISK="/dev/nvme0n1"
fi

# ── Summary & confirmation ────────────────────────────────────────────────────

printf "\n%b==> Summary of chosen values:%b\n" "$GREEN" "$NC"
printf "  %-12s %s\n" "user:"       "$CFG_USER"
printf "  %-12s %s\n" "name:"       "$CFG_NAME"
printf "  %-12s %s\n" "email:"      "$CFG_EMAIL"
printf "  %-12s %s\n" "isPersonal:" "$CFG_IS_PERSONAL"
printf "  %-12s %s\n" "hostName:"   "$CFG_HOSTNAME"
printf "  %-12s %s\n" "timeZone:"   "$CFG_TIMEZONE"
if [ "$OS" = "Linux" ]; then
  printf "  %-12s %s\n" "sshKeys:"    "$CFG_SSH_KEY"
  printf "  %-12s %s\n" "diskDevice:" "$CFG_DISK"
fi

printf "\n%b==> Add this SSH public key to GitHub as BOTH an Authentication%b\n" "$YELLOW" "$NC"
printf "%b    key AND a Signing key (separate forms — paste twice):%b\n" "$YELLOW" "$NC"
printf "    %s\n" "$SSH_PUBKEY"
printf "    https://github.com/settings/ssh/new\n"
printf "    https://github.com/settings/ssh/new?type=signing\n"
printf "%bPress Enter when added (or to skip)...%b" "$YELLOW" "$NC"
read -r _ack

printf "\n%bProceed with build-switch? [y/N]: %b" "$YELLOW" "$NC"
read -r _confirm
case "$_confirm" in
  y|Y) : ;;
  *)
    printf "%bhost.nix written but build skipped. Run manually:%b\n" "$YELLOW" "$NC"
    printf "  nix --extra-experimental-features 'nix-command flakes' run '.#build-switch'\n"
    # Still write host.nix before exiting so user can inspect / run manually
    ;;
esac

# ── Write host.nix ───────────────────────────────────────────────────────────

ESC_USER="$(nix_escape "$CFG_USER")"
ESC_NAME="$(nix_escape "$CFG_NAME")"
ESC_EMAIL="$(nix_escape "$CFG_EMAIL")"
ESC_HOSTNAME="$(nix_escape "$CFG_HOSTNAME")"
ESC_TIMEZONE="$(nix_escape "$CFG_TIMEZONE")"
ESC_SSH_KEY="$(nix_escape "$CFG_SSH_KEY")"
ESC_DISK="$(nix_escape "$CFG_DISK")"

cat > host.nix << HOSTNIX
{
  user = "${ESC_USER}";
  name = "${ESC_NAME}";
  email = "${ESC_EMAIL}";
  isPersonal = ${CFG_IS_PERSONAL};
  hostName = "${ESC_HOSTNAME}";
  timeZone = "${ESC_TIMEZONE}";
  sshKeys = [ "${ESC_SSH_KEY}" ];
  diskDevice = "${ESC_DISK}";
}
HOSTNIX

printf "%bhost.nix written to %s/host.nix%b\n" "$GREEN" "$REPO_DIR" "$NC"

# Exit early if user did not confirm
case "$_confirm" in
  y|Y) : ;;
  *)
    exit 0
    ;;
esac

# ── Build & switch ────────────────────────────────────────────────────────────

printf "%b==> Running build-switch...%b\n" "$GREEN" "$NC"
nix --extra-experimental-features 'nix-command flakes' run ".#build-switch"

# ── Local signature verification ─────────────────────────────────────────────
# Run after build-switch so home-manager has populated git user.email.

printf "%b==> Configuring local SSH signature verification...%b\n" "$GREEN" "$NC"
sh "${REPO_DIR}/scripts/setup-signature-verification.sh" "$CFG_EMAIL" || \
  printf "%bSignature verification setup failed (non-fatal).%b\n" "$YELLOW" "$NC"

printf "%b==> Bootstrap complete!%b\n" "$GREEN" "$NC"
