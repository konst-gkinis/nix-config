{ lib, ... }:

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
  home.file."Library/Application Support/iTerm2/DynamicProfiles/ayu-mirage.json".text =
    builtins.toJSON profileWithBg;

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
  '';
}
