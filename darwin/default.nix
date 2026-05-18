{
  config,
  pkgs,
  lib,
  home-manager,
  ...
}:

let
  user = "kg";
in

{
  imports = [
    ./dock
    ../shared/nixpkgs.nix
  ];

  security.pam.services.sudo_local.touchIdAuth = true;
  nix = {
    package = pkgs.nix;
    settings = {
      trusted-users = [
        "@admin"
        "${user}"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  environment.systemPackages = import ../shared/packages.nix { inherit pkgs; };

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  homebrew = {
    enable = true;
    casks = pkgs.callPackage ./casks.nix { };
    # onActivation.cleanup = "uninstall";
  };

  home-manager = {
    backupFileExtension = "backup";
    useGlobalPkgs = true;
    users.${user} =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        imports = [ ../shared/home.nix ];
        home = {
          enableNixpkgsReleaseCheck = false;
          packages = (import ../shared/packages.nix { inherit pkgs; }) ++ [
            pkgs.dockutil
          ];
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

      dock = {
        show-recents = false;
        launchanim = true;
        orientation = "bottom";
        tilesize = 75;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
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
