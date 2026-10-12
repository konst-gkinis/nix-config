{
  config,
  inputs,
  pkgs,
  user,
  fullName,
  email,
  workGitDir ? null,
  flakeDir,
  hostName,
  timeZone,
  sshKeys,
  ...
}:
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ../shared/nixpkgs.nix
    ../shared/nix-settings.nix
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
    };
    package = pkgs.nix;
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
    extraSpecialArgs = {
      inherit
        user
        fullName
        email
        workGitDir
        ;
    };
    users.${user} = {
      imports = [
        ../shared/home.nix
        ./home.nix
      ];
    };
  };

  environment.variables.NH_FLAKE = flakeDir;

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
