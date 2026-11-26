# macOS preferences (`defaults write`) managed by nix-darwin.
{ ... }:

{
  system.defaults = {
    NSGlobalDomain = {
      "com.apple.mouse.tapBehavior" = 1;

      # Keyboard → Text Input → Input Sources → Edit…
      NSAutomaticSpellingCorrectionEnabled = false; # "Correct spelling automatically"
      NSAutomaticCapitalizationEnabled = false; # "Capitalise words automatically"
      NSAutomaticPeriodSubstitutionEnabled = false; # "Add period with double-space"
    };

    controlcenter = {
      BatteryShowPercentage = true;
    };

    dock = {
      autohide = true;
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

    # No typed nix-darwin option for these.
    CustomUserPreferences = {
      NSGlobalDomain = {
        # Untick "Close windows when quitting an application": apps reopen their
        # windows after cmd-Q (iTerm2 then reattaches its still-running jobs).
        NSQuitAlwaysKeepsWindows = true;
      };

      # Keyboard → Text Input → Input Sources: ABC and Greek. The two input
      # methods are macOS's own (emoji/character viewer, press-and-hold accents).
      # Takes effect at next login, or straight away if the list already matches.
      "com.apple.HIToolbox" = {
        AppleEnabledInputSources = [
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = 252;
            "KeyboardLayout Name" = "ABC";
          }
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout ID" = -18944;
            "KeyboardLayout Name" = "Greek";
          }
          {
            InputSourceKind = "Non Keyboard Input Method";
            "Bundle ID" = "com.apple.CharacterPaletteIM";
          }
          {
            InputSourceKind = "Non Keyboard Input Method";
            "Bundle ID" = "com.apple.PressAndHold";
          }
        ];
      };
    };
  };
}
