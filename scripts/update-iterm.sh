#!/usr/bin/env bash
# Usage: ./scripts/update-iterm.sh ~/Desktop/iTerm2\ State.itermexport
set -euo pipefail

EXPORT="${1:-}"
if [[ -z "$EXPORT" ]]; then
  echo "Usage: $0 <path-to.itermexport>" >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ITERM_DIR="$REPO/darwin/iterm2"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

tar -xzf "$EXPORT" -C "$TMPDIR"

cp "$TMPDIR/user-defaults/UserDefaults.plist" "$ITERM_DIR/UserDefaults.plist"

# Fix background image path to the nix-managed location
plutil -replace "New Bookmarks.1.Background Image Location" \
  -string "/Users/kg/.config/iterm2/background.jpg" \
  "$ITERM_DIR/UserDefaults.plist"

if [[ -d "$TMPDIR/app-support/DynamicProfiles" ]]; then
  cp -r "$TMPDIR/app-support/DynamicProfiles/." "$ITERM_DIR/DynamicProfiles/"
fi

echo "Updated. Run: darwin-rebuild switch --flake $REPO"
