{ inputs, lib, ... }:

{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = false;
      allowInsecure = false;
      allowUnsupportedSystem = false;
    };

    overlays =
      let
        dir = ../overlays;
        # An overlay is either a *.nix file or a directory with a default.nix.
        isOverlay =
          name: type:
          lib.hasSuffix ".nix" name
          || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"));
        # Sorted by name, so a numeric prefix (10-foo.nix) sets the order.
        local = lib.mapAttrsToList (name: _: import (dir + "/${name}")) (
          lib.filterAttrs isOverlay (builtins.readDir dir)
        );
      in
      local
      ++ [
        inputs.claude-code.overlays.default
        inputs.nh.overlays.default
      ];
  };
}
