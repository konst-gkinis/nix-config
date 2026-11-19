{
  pkgs,
  lib,
  flakeDir,
  ...
}:

let
  # Writing-style skill. `nup --pins` bumps rev and hash (scripts/update-pins.sh).
  # nup --pins: follow main
  humanizer = pkgs.fetchFromGitHub {
    owner = "blader";
    repo = "humanizer";
    rev = "a48c60c2a3f7a0f6ecc8f9b8d2b1ef71c7927155";
    hash = "sha256-ql6zyupIPJaGtzHrVwGe7iqZKfdg/4YItv3FaDeYVe4=";
  };

  # Mods load from the working tree, not the store: Claude Code watches the
  # folder (an edit reloads it) and writes its type files beside the mod.
  managedSettings = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON {
      env.CLAUDE_CODE_PLUGIN_DIRS = "${flakeDir}/claude/mods/collapse-steps";
      # No Co-Authored-By trailer on commits Claude makes.
      attribution.commit = "";
    }
  );
in
{
  home.file = {
    ".claude/CLAUDE.md".source = ../../claude/CLAUDE.md;
    ".claude/statusline-command.sh" = {
      source = ../../claude/statusline-command.sh;
      executable = true;
    };
    ".claude/themes/ayu-dark.json".source = ../../claude/themes/ayu-dark.json;
    ".claude/skills/humanizer/SKILL.md".source = "${humanizer}/SKILL.md";
  };

  # Keep ~/.claude/settings.json a plain, writeable file (Claude Code writes to it
  # directly, e.g. to persist permission grants) instead of a read-only Nix store
  # symlink. Recursively merge the repo's defaults into it on every activation,
  # with the live file winning on any conflicting key, except the managed keys,
  # which always take the repo's value.
  home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.claude/settings.json"
    defaults="${../../claude/settings.json}"
    if [ ! -f "$target" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$target")"
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$defaults" "${managedSettings}" > "$tmp"
      $DRY_RUN_CMD mv -f "$tmp" "$target"
    else
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq -s '.[0] * .[1] * .[2]' "$defaults" "$target" "${managedSettings}" > "$tmp"
      # -f: the target may be read-only (files copied out of the Nix store keep
      # mode 0444), which otherwise makes mv prompt and fail activation.
      $DRY_RUN_CMD mv -f "$tmp" "$target"
    fi
    # Claude Code must be able to write this file itself.
    $DRY_RUN_CMD chmod u+w "$target"

    # Sessions started with CLAUDE_CONFIG_DIR=~/.claude-home (set by their
    # launcher, not by this repo) never read ~/.claude, so the managed keys go
    # there too. Only into an existing file: the launcher owns that directory.
    alt="$HOME/.claude-home/settings.json"
    if [ -f "$alt" ]; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$alt" "${managedSettings}" > "$tmp"
      $DRY_RUN_CMD mv -f "$tmp" "$alt"
      $DRY_RUN_CMD chmod u+w "$alt"
    fi
  '';
}
