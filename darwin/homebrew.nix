# Homebrew casks and brews. The cask lists live in ./casks.nix and
# ./casks-personal.nix so adding an app touches only a plain list.
{
  lib,
  isPersonal ? false,
  ...
}:

let
  casks = import ./casks.nix;
  casksPersonal = import ./casks-personal.nix;
in

{
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
}
