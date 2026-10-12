# macOS preferences (`defaults write`) managed by nix-darwin.
{ ... }:

{
  system.defaults = {
    NSGlobalDomain = {
      "com.apple.mouse.tapBehavior" = 1;
    };

    controlcenter = {
      BatteryShowPercentage = true;
    };

    dock = {
      show-recents = false;
      launchanim = true;
      orientation = "bottom";
      tilesize = 75;
    };

    finder = {
      _FXShowPosixPathInTitle = false;
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      NewWindowTarget = "Home";
    };

    trackpad = {
      Clicking = true;
    };
  };
}
