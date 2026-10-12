# Daily 09:00 notification when a watched package (claude-code) has a newer
# version on nixpkgs-unstable than the one pinned in flake.lock.
{ pkgs, ... }:

let
  pkgUpdateCheck = pkgs.writeShellScript "nix-pkg-update-check" ''
    export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

    # The lock this generation was built from, so the check compares against
    # what is installed rather than whatever the working tree holds.
    PINNED_REV=$(${pkgs.jq}/bin/jq -r '.nodes.nixpkgs.locked.rev' ${../../flake.lock})

    PACKAGES=(claude-code)
    UPDATES=()

    for pkg in "''${PACKAGES[@]}"; do
      current=$(nix eval --raw "github:NixOS/nixpkgs/''${PINNED_REV}#''${pkg}.version" 2>/dev/null)
      latest=$(nix eval --raw "github:NixOS/nixpkgs/nixpkgs-unstable#''${pkg}.version" 2>/dev/null)
      if [ -n "$current" ] && [ -n "$latest" ] && [ "$current" != "$latest" ]; then
        UPDATES+=("$pkg: $current → $latest")
      fi
    done

    if [ "''${#UPDATES[@]}" -gt 0 ]; then
      MSG=$(printf '%s\n' "''${UPDATES[@]}")
      ${pkgs.terminal-notifier}/bin/terminal-notifier \
        -title "Nix Package Updates Available" \
        -message "$MSG" \
        -sound default
    fi
  '';
in
{
  launchd.agents.nix-pkg-update-check = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgUpdateCheck}" ];
      StartCalendarInterval = [
        {
          Hour = 9;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/nix-pkg-update-check.log";
      StandardErrorPath = "/tmp/nix-pkg-update-check.log";
    };
  };
}
