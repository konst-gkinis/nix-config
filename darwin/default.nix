{
  pkgs,
  lib,
  user,
  flakeDir,
  isPersonal ? false,
  ...
}:

let
  casks = import ./casks.nix;
  casksPersonal = import ./casks-personal.nix;
in

{
  imports = [
    ./dock
    ../shared/nixpkgs.nix
    ../shared/nix-settings.nix
    ../shared/home-manager.nix
  ];

  security.pam.services.sudo_local.touchIdAuth = true;
  nix = {
    package = pkgs.lixPackageSets.stable.lix;
    settings = {
      trusted-users = [
        "@admin"
        "${user}"
      ];
    };
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 1d";
    };
  };

  environment.variables.NH_FLAKE = flakeDir;

  environment.systemPackages =
    (import ../shared/packages.nix { inherit pkgs; }) ++ (import ./packages.nix { inherit pkgs; });

  # Installed into /Library/Fonts/Nix Fonts. Font packages in systemPackages
  # never reach macOS's font list, so iTerm2 couldn't select them.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  homebrew = {
    enable = true;
    casks = casks ++ lib.optionals isPersonal casksPersonal;
    brews = [
      "python3"
      "uv"
      # tw93/mole: homebrew-core formula, not a cask; nixpkgs `mole` is an unrelated SSH-tunnel tool
      "mole"
    ];
    # onActivation.cleanup = "uninstall";
  };

  home-manager = {
    backupFileExtension = "backup";
    users.${user}.imports = [ ./home.nix ];
  };

  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 5;

    defaults = {
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
  };

  local.dock = {
    enable = false;
    username = user;
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Creating Spotlight-indexable aliases for Home Manager apps..." >&2
    hm_apps="/Users/${user}/Applications/Home Manager Apps"
    wrappers="/Users/${user}/Applications/Home Manager App Wrappers"
    rm -rf "$wrappers"
    mkdir -p "$wrappers"
    if [ -d "$hm_apps" ]; then
      find "$hm_apps" -maxdepth 1 -name "*.app" | while read -r app; do
        ${pkgs.mkalias}/bin/mkalias "$app" "$wrappers/$(basename "$app")"
      done
    fi
  '';
}
