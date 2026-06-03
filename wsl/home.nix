{
  pkgs,
  user,
  ...
}:
{
  home = {
    enableNixpkgsReleaseCheck = false;
    username = user;
    homeDirectory = "/home/${user}";
    packages = import ./packages.nix { inherit pkgs; };
    stateVersion = "25.11";
  };
}
