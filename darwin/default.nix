{
  config,
  pkgs,
  lib,
  home-manager,
  user,
  fullName,
  email,
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
  ];

  security.pam.services.sudo_local.touchIdAuth = true;
  nix = {
    package = pkgs.lixPackageSets.stable.lix;
    settings = {
      trusted-users = [
        "@admin"
        "${user}"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  environment.systemPackages = (import ../shared/packages.nix { inherit pkgs; }) ++ [
    pkgs.pinentry_mac
    pkgs.terminal-notifier
  ];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  homebrew = {
    enable = true;
    casks = casks ++ lib.optionals isPersonal casksPersonal;
    # onActivation.cleanup = "uninstall";
  };

  home-manager = {
    backupFileExtension = "backup";
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit user fullName email; };
    users.${user} =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        imports = [
          ../shared/home.nix
          ./home.nix
        ];
        home = {
          enableNixpkgsReleaseCheck = false;
          packages = [ pkgs.dockutil ];
          stateVersion = "23.11";
        };
      };
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
        TrackpadThreeFingerDrag = true;
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
