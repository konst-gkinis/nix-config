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
REPO_DIR="${HOME}/repos/nix-config"

# Prompts use gum when it could be fetched (set in "Prompt UI" below) and fall
# back to plain `read`, so a failed fetch never blocks a bootstrap. gum draws on
# stderr and prints the answer on stdout, so it works inside $(...).
GUM=""

# Helper: prompt with a default value
# Usage: result=$(ask "Prompt text" "default value")
ask() {
  _prompt="$1"
  _default="$2"
  if [ -n "$GUM" ]; then
    # Esc / Ctrl-C returns non-zero, which set -e turns into an abort.
    _answer="$("$GUM" input --header "$_prompt" --value "$_default" --width 0)" || return
  else
    printf "%b%s [%s]: %b" "$YELLOW" "$_prompt" "$_default" "$NC" >&2
    read -r _answer
  fi
  if [ -z "$_answer" ]; then
    printf "%s" "$_default"
  else
    printf "%s" "$_answer"
  fi
}

# Helper: yes/no question; succeeds on yes.
# Usage: if confirm "Question?" yes|no; then ...
confirm() {
  _prompt="$1"
  _default="$2"
  if [ -n "$GUM" ]; then
    _rc=0
    if [ "$_default" = "no" ]; then
      "$GUM" confirm --default=false "$_prompt" || _rc=$?
    else
      "$GUM" confirm "$_prompt" || _rc=$?
    fi
    # 0 = yes, 1 = no, anything else (130 on Ctrl-C) aborts.
    [ "$_rc" -le 1 ] || exit "$_rc"
    return "$_rc"
  fi
  if [ "$_default" = "no" ]; then _hint="y/N"; else _hint="Y/n"; fi
  printf "%b%s [%s]: %b" "$YELLOW" "$_prompt" "$_hint" "$NC" >&2
  read -r _ans
  case "$_ans" in
    y|Y|yes|YES|Yes) return 0 ;;
    n|N|no|NO|No)    return 1 ;;
    *) [ "$_default" != "no" ] ;;
  esac
}

# Helper: read a secret without echoing it.
# Usage: secret=$(ask_secret "Prompt text")
ask_secret() {
  if [ -n "$GUM" ]; then
    "$GUM" input --password --header "$1" --width 0
    return
  fi
  printf "%b%s: %b" "$YELLOW" "$1" "$NC" >&2
  trap 'stty echo; exit 130' INT
  stty -echo
  read -r _secret
  stty echo
  trap - INT
  printf "\n" >&2
  printf "%s" "$_secret"
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

  # Ensure Nix. Lix, to match nix.package in darwin/nix.nix. Do not use the
  # Determinate Systems installer: it now installs Determinate Nix, its daemon
  # conflicts with nix-darwin abort activation.
  if ! command -v nix > /dev/null 2>&1; then
    printf "%bNix not found. Installing Lix...%b\n" "$YELLOW" "$NC"
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.lix.systems/lix \
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

# ── Prompt UI ────────────────────────────────────────────────────────────────
# gum from the nixpkgs pinned in flake.lock, so the download is shared with
# build-switch. path:. because host.nix may already exist (see CLAUDE.md).

# gum's masked input panics on a terminal that reports 0 columns (some serial
# consoles), so require a real width as well as a TTY.
_cols="$(stty size 2>/dev/null | cut -d' ' -f2)"
if [ -t 0 ] && [ -t 2 ] && [ "${_cols:-0}" -gt 0 ]; then
  printf "%b==> Fetching gum for the prompts...%b\n" "$GREEN" "$NC"
  if _gum_out="$(nix --extra-experimental-features 'nix-command flakes' build \
        --no-link --print-out-paths --inputs-from path:. nixpkgs#gum 2>/dev/null)" \
     && [ -x "${_gum_out}/bin/gum" ]; then
    GUM="${_gum_out}/bin/gum"
  else
    printf "%bCould not fetch gum; using plain prompts.%b\n" "$YELLOW" "$NC"
  fi
fi

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
if confirm "Personal machine?" yes; then
  CFG_IS_PERSONAL="true"
else
  CFG_IS_PERSONAL="false"
fi

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
# Comment identifies which machine a key came from, so keys can be told apart
# (and revoked individually) in an authorized_keys file.
SSH_KEY_COMMENT="${CFG_EMAIL} (${CFG_HOSTNAME})"
if [ ! -f "$SSH_KEY_PATH" ]; then
  printf "%b==> No SSH key at %s — generating ed25519 keypair...%b\n" "$GREEN" "$SSH_KEY_PATH" "$NC"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  # The passphrase is read masked and kept in a shell variable only: never
  # echoed, written to disk or exported. ssh-keygen has no stdin/askpass input,
  # so it gets it via -N, i.e. on its argv for the instant it runs.
  _key_pass=""
  if confirm "Protect the private key with a passphrase?" yes; then
    while :; do
      _key_pass="$(ask_secret "Key passphrase")"
      if [ -z "$_key_pass" ]; then
        printf "%bPassphrase can't be empty.%b\n" "$RED" "$NC" >&2
        continue
      fi
      _key_pass2="$(ask_secret "Repeat passphrase")"
      [ "$_key_pass" = "$_key_pass2" ] && break
      printf "%bPassphrases don't match, try again.%b\n" "$RED" "$NC" >&2
    done
    unset _key_pass2
  fi
  ssh-keygen -q -t ed25519 -C "$SSH_KEY_COMMENT" -N "$_key_pass" -f "$SSH_KEY_PATH"
  if [ "$OS" = "Darwin" ] && [ -n "$_key_pass" ]; then
    # Store the passphrase in the macOS Keychain so signing/auth is
    # friction-free. ssh-add takes it from a throwaway askpass helper that
    # reads it from ssh-add's environment (visible to this user only), so it
    # isn't typed a third time. The helper itself holds no secret.
    _askpass="$(mktemp)"
    # shellcheck disable=SC2016  # $BOOTSTRAP_KEY_PASS expands in the helper
    printf '#!/bin/sh\nprintf "%%s\\n" "$BOOTSTRAP_KEY_PASS"\n' > "$_askpass"
    chmod 700 "$_askpass"
    BOOTSTRAP_KEY_PASS="$_key_pass" SSH_ASKPASS="$_askpass" SSH_ASKPASS_REQUIRE=force \
      DISPLAY="${DISPLAY:-:0}" ssh-add -q --apple-use-keychain "$SSH_KEY_PATH" < /dev/null \
      || printf "%bCould not add the key to the Keychain (non-fatal).%b\n" "$YELLOW" "$NC"
    rm -f "$_askpass"
  fi
  unset _key_pass
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
    DEFAULT_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICz8fpWR17uro4SHsoQJHwAJvERwaiKvSwddpj4jCD8A konst.gkinis@gmail.com (KG-air)"
  fi
  CFG_SSH_KEY="$(ask "SSH authorized public key" "$DEFAULT_SSH_KEY")"

  # Disk device: pick from the list with gum, else type it.
  _disks="$(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null || true)"
  if [ -n "$GUM" ] && [ -n "$_disks" ]; then
    _default_disk="$(printf "%s\n" "$_disks" | grep '^/dev/nvme0n1 ' || true)"
    _disk_line="$(printf "%s\n" "$_disks" \
      | "$GUM" choose --header "Disk device" --selected "$_default_disk")"
    CFG_DISK="${_disk_line%% *}"
  else
    printf "%bAvailable block devices:%b\n" "$YELLOW" "$NC"
    printf "%s\n" "$_disks"
    CFG_DISK="$(ask "Disk device" "/dev/nvme0n1")"
  fi
else
  # macOS — use defaults from flake settings
  CFG_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICz8fpWR17uro4SHsoQJHwAJvERwaiKvSwddpj4jCD8A konst.gkinis@gmail.com (KG-air)"
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
confirm "Added it to GitHub? (either answer continues)" yes || true

PROCEED=1
confirm "Proceed with build-switch?" yes || PROCEED=0

# ── Write host.nix ───────────────────────────────────────────────────────────

ESC_USER="$(nix_escape "$CFG_USER")"
ESC_NAME="$(nix_escape "$CFG_NAME")"
ESC_EMAIL="$(nix_escape "$CFG_EMAIL")"
ESC_HOSTNAME="$(nix_escape "$CFG_HOSTNAME")"
ESC_TIMEZONE="$(nix_escape "$CFG_TIMEZONE")"
ESC_SSH_KEY="$(nix_escape "$CFG_SSH_KEY")"
ESC_DISK="$(nix_escape "$CFG_DISK")"
ESC_REPO_DIR="$(nix_escape "$REPO_DIR")"

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
  flakeDir = "${ESC_REPO_DIR}";
}
HOSTNIX

printf "%bhost.nix written to %s/host.nix%b\n" "$GREEN" "$REPO_DIR" "$NC"

# Exit early if user declined; host.nix is kept so it can be inspected first.
if [ "$PROCEED" = "0" ]; then
  printf "%bBuild skipped. Run manually:%b\n" "$YELLOW" "$NC"
  printf "  cd %s\n" "$REPO_DIR"
  printf "  nix --extra-experimental-features 'nix-command flakes' run '.#build-switch'\n"
  printf "  sh scripts/setup-signature-verification.sh '%s'\n" "$CFG_EMAIL"
  exit 0
fi

# ── Build & switch ────────────────────────────────────────────────────────────

printf "%b==> Running build-switch...%b\n" "$GREEN" "$NC"
nix --extra-experimental-features 'nix-command flakes' run ".#build-switch"

# ── Local signature verification ─────────────────────────────────────────────
# Run after build-switch so home-manager has populated git user.email.

printf "%b==> Configuring local SSH signature verification...%b\n" "$GREEN" "$NC"
sh "${REPO_DIR}/scripts/setup-signature-verification.sh" "$CFG_EMAIL" || \
  printf "%bSignature verification setup failed (non-fatal).%b\n" "$YELLOW" "$NC"

printf "%b==> Bootstrap complete!%b\n" "$GREEN" "$NC"
