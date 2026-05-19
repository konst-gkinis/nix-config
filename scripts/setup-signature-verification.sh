#!/bin/sh
# Configure local verification of SSH-signed git commits.
#
# Writes ~/.config/git/allowed_signers mapping your git email to your
# ~/.ssh/id_ed25519.pub, and points git at it via gpg.ssh.allowedSignersFile.
# Idempotent: safe to run multiple times.
#
# Standalone usage:
#   ./scripts/setup-signature-verification.sh
#   ./scripts/setup-signature-verification.sh you@example.com  # override email

set -e

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

SSH_PUBKEY_PATH="${HOME}/.ssh/id_ed25519.pub"
ALLOWED_SIGNERS="${HOME}/.config/git/allowed_signers"

if [ ! -f "$SSH_PUBKEY_PATH" ]; then
  printf "%bNo SSH pubkey at %s — skipping verification setup.%b\n" \
    "$RED" "$SSH_PUBKEY_PATH" "$NC"
  exit 1
fi

EMAIL="${1:-$(git config --global --get user.email 2>/dev/null || true)}"
if [ -z "$EMAIL" ]; then
  printf "%bgit user.email is unset and no email argument given.%b\n" "$RED" "$NC"
  printf "Run: %s your@email.com\n" "$0"
  exit 1
fi

PUBKEY="$(cat "$SSH_PUBKEY_PATH")"
ENTRY="${EMAIL} ${PUBKEY}"

mkdir -p "$(dirname "$ALLOWED_SIGNERS")"
touch "$ALLOWED_SIGNERS"

if grep -qxF "$ENTRY" "$ALLOWED_SIGNERS"; then
  printf "%bEntry for %s already present in %s%b\n" \
    "$GREEN" "$EMAIL" "$ALLOWED_SIGNERS" "$NC"
else
  printf "%s\n" "$ENTRY" >> "$ALLOWED_SIGNERS"
  printf "%bAdded entry for %s to %s%b\n" \
    "$GREEN" "$EMAIL" "$ALLOWED_SIGNERS" "$NC"
fi

git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"

printf "%bLocal SSH signature verification is configured.%b\n" "$GREEN" "$NC"
printf "%bTry: git log --show-signature -1%b\n" "$YELLOW" "$NC"
