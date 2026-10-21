# nix-darwin system config. Each concern lives in its own module; this file
# holds the user, packages and the wiring between them.
{
  pkgs,
  user,
  flakeDir,
  ...
}:

{
  imports = [
    ./dock
    ./nix.nix
    ./homebrew.nix
    ./macos-defaults.nix
    ./app-aliases.nix
    ../shared/nixpkgs.nix
    ../shared/nix-settings.nix
    ../shared/pki.nix
    ../shared/home-manager.nix
  ];

  security.pam.services.sudo_local.touchIdAuth = true;

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

  home-manager = {
    backupFileExtension = "backup";
    users.${user}.imports = [ ./home.nix ];
  };

  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 5;
  };

  local.dock = {
    enable = false;
    username = user;
  };
}
