# VS Code: settings that home-manager does not own the file for.
{ pkgs, lib, ... }:

{
  # Prevents garbled text in VS Code's integrated terminal when using Claude Code
  home.activation.vscodeClaudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/Library/Application Support/Code/User/settings.json"
    if [ -f "$settings" ]; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '."terminal.integrated.gpuAcceleration" = "off"' "$settings" > "$tmp" \
        && mv "$tmp" "$settings"
    fi
  '';
}
