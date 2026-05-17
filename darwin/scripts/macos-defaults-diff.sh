#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_DIR="${HOME}/.local/share/macos-defaults-snapshot"
CMD="${1:-}"

# Export all defaults domains as sorted JSON files into a directory.
# Sorted JSON ensures the diff only shows genuine value changes, not reordering.
dump_all() {
    local dir="$1"
    mkdir -p "$dir"
    {
        defaults domains 2>/dev/null | tr ',' '\n' | sed 's/^ //;s/ $//'
        printf 'NSGlobalDomain\n'
    } | sort -u | while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        defaults export "$domain" - 2>/dev/null \
            | plutil -convert json - -o - 2>/dev/null \
            | jq --sort-keys . > "${dir}/${domain}.json" 2>/dev/null \
            || rm -f "${dir}/${domain}.json"
    done
}

# Map a defaults domain to the closest nix-darwin system.defaults path.
nix_attr() {
    case "$1" in
        NSGlobalDomain)
            echo "system.defaults.NSGlobalDomain" ;;
        com.apple.dock)
            echo "system.defaults.dock" ;;
        com.apple.finder)
            echo "system.defaults.finder" ;;
        com.apple.AppleMultitouchTrackpad|com.apple.driver.AppleBluetoothMultitouch.trackpad)
            echo "system.defaults.trackpad" ;;
        com.apple.screencapture)
            echo "system.defaults.screencapture" ;;
        com.apple.screensaver)
            echo "system.defaults.screensaver" ;;
        com.apple.spaces)
            echo "system.defaults.spaces" ;;
        com.apple.universalaccess)
            echo "system.defaults.universalaccess" ;;
        com.apple.loginwindow|loginwindow)
            echo "system.defaults.loginwindow" ;;
        com.apple.SoftwareUpdate)
            echo "system.defaults.SoftwareUpdate" ;;
        com.apple.WindowManager)
            echo "system.defaults.WindowManager" ;;
        com.apple.ActivityMonitor)
            echo "system.defaults.ActivityMonitor" ;;
        com.apple.LaunchServices)
            echo "system.defaults.LaunchServices" ;;
        com.apple.Safari)
            echo "system.defaults.Safari" ;;
        *)
            echo "system.defaults.CustomUserPreferences.\"${1}\"" ;;
    esac
}

case "$CMD" in
    snapshot)
        rm -rf "${SNAPSHOT_DIR}/before"
        printf 'Snapshotting macOS defaults (this takes a few seconds)...\n'
        dump_all "${SNAPSHOT_DIR}/before"
        printf 'Done. Change your settings, then run: macos-defaults-diff diff\n'
        ;;
    diff)
        if [[ ! -d "${SNAPSHOT_DIR}/before" ]]; then
            printf 'No snapshot found. Run: macos-defaults-diff snapshot\n' >&2
            exit 1
        fi
        tmp_dir=$(mktemp -d)
        trap 'rm -rf "$tmp_dir"' EXIT

        printf 'Reading current defaults...\n'
        dump_all "$tmp_dir"

        changed=0
        for new_file in "$tmp_dir"/*.json; do
            [[ -f "$new_file" ]] || continue
            domain=$(basename "$new_file" .json)
            old_file="${SNAPSHOT_DIR}/before/${domain}.json"

            if [[ ! -f "$old_file" ]]; then
                printf '\n━━━ %s (new domain)\n' "$domain"
                printf '    Nix: %s\n' "$(nix_attr "$domain")"
                changed=1
                continue
            fi

            if ! diff -q "$old_file" "$new_file" >/dev/null 2>&1; then
                printf '\n━━━ %s\n' "$domain"
                printf '    Nix: %s.<key>\n\n' "$(nix_attr "$domain")"
                # -U 0: no context lines, just the changed values
                diff -U 0 "$old_file" "$new_file" \
                    | grep -Ev '^(---|\+\+\+|@@)' \
                    || true
                changed=1
            fi
        done

        [[ $changed -eq 0 ]] && printf 'No changes detected.\n'
        ;;
    -h|--help|"")
        cat <<'EOF'
USAGE
    macos-defaults-diff snapshot
    macos-defaults-diff diff
    macos-defaults-diff -h

DESCRIPTION
    Helps you translate macOS System Settings changes into nix-darwin config.

    Workflow:
      1. Run `snapshot` before opening System Settings.
      2. Change whatever you like in the UI.
      3. Run `diff` to see exactly which defaults keys changed and which
         nix-darwin option controls them.

COMMANDS
    snapshot
        Exports every defaults domain as sorted JSON and saves it as a
        baseline. The snapshot is stored in:
            ~/.local/share/macos-defaults-snapshot/before/

    diff
        Re-exports all domains, compares against the baseline, and prints
        each changed domain with:
          - The closest nix-darwin attribute path (e.g. system.defaults.dock)
          - The exact key/value lines that changed (- old, + new)

        For domains nix-darwin knows about (dock, finder, NSGlobalDomain,
        trackpad, screencapture, etc.) the path is a first-class option.
        For everything else it falls back to:
            system.defaults.CustomUserPreferences."<domain>".<key>

EXAMPLE
    $ macos-defaults-diff snapshot
    Snapshotting macOS defaults (this takes a few seconds)...
    Done. Change your settings, then run: macos-defaults-diff diff

    # (open System Settings → Dock → change Size to 64)

    $ macos-defaults-diff diff
    Reading current defaults...

    ━━━ com.apple.dock
        Nix: system.defaults.dock.<key>

    -  "tilesize": 48,
    +  "tilesize": 64,

NOTES
    Snapshots are sorted JSON, so reordering inside a domain never produces
    false positives. Only genuine value changes appear in the diff.

    Some System Settings panels (Privacy, iCloud, etc.) write to locations
    outside the defaults system and will not appear in the diff.
EOF
        ;;
    *)
        printf 'Unknown command: %s\nRun: macos-defaults-diff --help\n' "$CMD" >&2
        exit 1
        ;;
esac
