{
  lib,
  pkgs,
  user,
  ...
}:

let
  flakeDir = "/Users/${user}/nixos-config";

  pkgUpdateCheck = pkgs.writeShellScript "nix-pkg-update-check" ''
    export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

    PINNED_REV=$(${pkgs.jq}/bin/jq -r '.nodes.nixpkgs.locked.rev' "${flakeDir}/flake.lock")

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

  # Blurred so fine detail doesn't compete with the glyphs drawn over it. The
  # darkening is the profile's "Blend" (0 = only the background colour), which
  # stays tunable in iTerm2's UI without a rebuild.
  bgImage = pkgs.runCommand "iterm_background.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick ${./iterm2/iterm_background.jpg} -blur 0x3 -quality 92 $out
  '';
  profileJson = builtins.fromJSON (builtins.readFile ./iterm2/DynamicProfiles/ayu-mirage.json);
  profileWithBg = profileJson // {
    Profiles = map (p: p // { "Background Image Location" = toString bgImage; }) profileJson.Profiles;
  };
in
{
  home.file = {
    "Library/Application Support/iTerm2/DynamicProfiles/ayu-mirage.json".text =
      builtins.toJSON profileWithBg;
    ".iterm2_shell_integration.zsh".source = pkgs.fetchurl {
      url = "https://iterm2.com/shell_integration/zsh";
      sha256 = "sha256-kQJ8bVIh7nEjYJ6OWqiEDqIY+YWD5RbD1CXV+KKyDno=";
    };
  };

  programs.zsh.initContent = ''
    # iTerm2 shell integration — enables Claude Code terminal awareness (OSC 1337).
    # VS Code integration is automatic via TERM_PROGRAM=vscode set by VS Code itself.
    test -e ~/.iterm2_shell_integration.zsh && source ~/.iterm2_shell_integration.zsh
  '';

  # programs.zed-editor = {
  #   enable = true;
  #   extensions = [
  #     "nix"
  #     "terraform"
  #     "catppuccin"
  #     "catppuccin-icons"
  #     "codebook"
  #     "monokai-og"
  #     "ayu-darker"
  #   ];
  # };

  # iTerm2 reads these global prefs at launch only (the dynamic profile, by
  # contrast, reloads live). The activation records a hash of the commands and
  # drops a flag when it changes; build-switch restarts iTerm2 only then.
  home.activation.itermDefaults =
    let
      commands = ''
        run /usr/bin/defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "ayu-mirage"
        run /usr/bin/defaults write com.googlecode.iterm2 "Default Browser Profile Guid" -string "ayu-mirage"
        run /usr/bin/defaults write com.googlecode.iterm2 HideTab -bool true
        run /usr/bin/defaults write com.googlecode.iterm2 HideMenuBarInFullscreen -bool true
        run /usr/bin/defaults write com.googlecode.iterm2 CopySelection -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 EnableProxyIcon -bool true
        run /usr/bin/defaults write com.googlecode.iterm2 HideScrollbar -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 DimBackgroundWindows -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 DimOnlyText -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 HapticFeedbackForEsc -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 SoundForEsc -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 VisualIndicatorForEsc -bool false
        run /usr/bin/defaults write com.googlecode.iterm2 TabStyleWithAutomaticOption -int 4
        run /usr/bin/defaults write com.googlecode.iterm2 ApplePressAndHoldEnabled -bool false
        # Required for Claude Code's /copy command (OSC 52 clipboard writes)
        run /usr/bin/defaults write com.googlecode.iterm2 AllowClipboardAccess -bool true
        run /usr/bin/defaults write com.googlecode.iterm2 Hotkey -bool false
        run /usr/bin/defaults delete com.googlecode.iterm2 HotkeyChar 2>/dev/null || true
        run /usr/bin/defaults delete com.googlecode.iterm2 HotkeyCode 2>/dev/null || true
        run /usr/bin/defaults delete com.googlecode.iterm2 HotkeyModifiers 2>/dev/null || true
        run /usr/bin/defaults write com.googlecode.iterm2 AlternateMouseScroll -bool true
        # Session restoration: iTerm2 runs each session's job in a detached server
        # process (RunJobsInServers), so the job outlives the window.
        # KillJobsInServersOnQuit=false stops a user-initiated cmd-Q from killing
        # those jobs, so e.g. a running `claude` is still there when iTerm2
        # relaunches and reattaches. Both are Prefs > Advanced settings.
        run /usr/bin/defaults write com.googlecode.iterm2 RunJobsInServers -bool true
        run /usr/bin/defaults write com.googlecode.iterm2 KillJobsInServersOnQuit -bool false
        # Claude Code workgroup (Chat / Diff / Code Review panes). iTerm2 stores this
        # as an opaque base64 blob, so the readable source of truth is the JSON in the
        # repo, hex-encoded here for `defaults write -data`. The profile-level triggers
        # that activate it live in iterm2/DynamicProfiles/ayu-mirage.json.
        run /usr/bin/defaults write com.googlecode.iterm2 Workgroups -data "$(/usr/bin/od -An -tx1 -v ${./iterm2/workgroups.json} | tr -d ' \n')"
      '';
      hash = builtins.hashString "sha256" commands;
      stateDir = "$HOME/.local/state/nixos-config";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${commands}
      if [[ "$(cat "${stateDir}/iterm-defaults" 2>/dev/null)" != ${hash} ]]; then
        run mkdir -p "${stateDir}"
        run touch "${stateDir}/iterm-restart-needed"
        run /bin/sh -c 'printf %s "$1" > "$2"' _ ${hash} "${stateDir}/iterm-defaults"
      fi
    '';

  # Prevents garbled text in VS Code's integrated terminal when using Claude Code
  home.activation.vscodeClaudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/Library/Application Support/Code/User/settings.json"
    if [ -f "$settings" ]; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '."terminal.integrated.gpuAcceleration" = "off"' "$settings" > "$tmp" \
        && mv "$tmp" "$settings"
    fi
  '';

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
