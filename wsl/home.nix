{
  pkgs,
  user,
  ...
}:
{
  home = {
    username = user;
    homeDirectory = "/home/${user}";
    packages =
      (import ../shared/packages.nix { inherit pkgs; }) ++ (import ./packages.nix { inherit pkgs; });
    stateVersion = "25.11";
  };
}
