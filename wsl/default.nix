{
  config,
  inputs,
  pkgs,
  user,
  fullName,
  email,
  hostName,
  timeZone,
  sshKeys,
  ...
}:
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../shared/nixpkgs.nix
  ];

  wsl = {
    enable = true;
    defaultUser = user;
  };

  time.timeZone = timeZone;

  networking.hostName = hostName;

  nix = {
    settings = {
      allowed-users = [ "${user}" ];
      trusted-users = [
        "@wheel"
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
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs = {
    gnupg.agent.enable = true;
    zsh.enable = true;
  };

  services.openssh.enable = true;

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = sshKeys;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit user fullName email; };
    users.${user} = {
      imports = [
        ../shared/home.nix
        ./home.nix
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    gitFull
    inetutils
  ];

  security.sudo = {
    enable = true;
    extraRules = [
      {
        commands = [
          {
            command = "${pkgs.systemd}/bin/reboot";
            options = [ "NOPASSWD" ];
          }
        ];
        groups = [ "wheel" ];
      }
    ];
  };

  fonts.packages = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-color-emoji
    meslo-lgs-nf
  ];

  system.stateVersion = "25.11";
}
