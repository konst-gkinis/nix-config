# Nix daemon: Lix, trusted users and the weekly garbage collection.
{ pkgs, user, ... }:

{
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
}
