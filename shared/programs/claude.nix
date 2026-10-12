{
  pkgs,
  lib,
  flakeDir,
  ...
}:

let
  # Mods load from the working tree, not the store: Claude Code watches the
  # folder (an edit reloads it) and writes its type files beside the mod.
  managedSettings = pkgs.writeText "claude-managed-settings.json" (
    builtins.toJSON {
      env.CLAUDE_CODE_PLUGIN_DIRS = "${flakeDir}/claude/mods/collapse-steps";
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
