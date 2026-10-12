{
  pkgs,
  lib,
  ...
}:

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
  # with the live file winning on any conflicting key.
  home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.claude/settings.json"
    defaults="${../../claude/settings.json}"
    if [ ! -f "$target" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$target")"
      $DRY_RUN_CMD cp "$defaults" "$target"
    else
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$defaults" "$target" > "$tmp"
      # -f: the target may be read-only (files copied out of the Nix store keep
      # mode 0444), which otherwise makes mv prompt and fail activation.
      $DRY_RUN_CMD mv -f "$tmp" "$target"
    fi
    # Claude Code must be able to write this file itself.
    $DRY_RUN_CMD chmod u+w "$target"
  '';
}
