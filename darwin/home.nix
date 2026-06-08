{ lib, pkgs, ... }:

let
  bgImage = builtins.path {
    path = ./iterm2/iterm_background.jpg;
    name = "iterm_background.jpg";
  };
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

  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "terraform"
      "catppuccin"
      "catppuccin-icons"
      "codebook"
      "monokai-og"
      "ayu-darker"
    ];
  };

  home.activation.itermDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
    # Global hotkey: Ctrl+` to show/hide iTerm2
    run /usr/bin/defaults write com.googlecode.iterm2 Hotkey -bool true
    run /usr/bin/defaults write com.googlecode.iterm2 HotkeyChar -int 96
    run /usr/bin/defaults write com.googlecode.iterm2 HotkeyCode -int 50
    run /usr/bin/defaults write com.googlecode.iterm2 HotkeyModifiers -int 262144
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
}
