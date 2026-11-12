# Homebrew casks and brews. The cask lists live in ./casks.nix and
# ./casks-personal.nix so adding an app touches only a plain list.
# Casks marked with `loginItem` there also get a launchd agent that opens the
# app at login, so removing the cask removes its login item too.
{
  lib,
  isPersonal ? false,
  ...
}:

let
  entries = import ./casks.nix ++ lib.optionals isPersonal (import ./casks-personal.nix);
  caskName = e: if builtins.isString e then e else e.name;
  loginItems = builtins.filter (e: builtins.isAttrs e && e ? loginItem) entries;
in

{
  homebrew = {
    enable = true;
    casks = map caskName entries;
    brews = [
      "python3"
      "uv"
      # tw93/mole: homebrew-core formula, not a cask; nixpkgs `mole` is an unrelated SSH-tunnel tool
      "mole"
    ];
    # onActivation.cleanup = "uninstall";
  };

  launchd.user.agents = lib.listToAttrs (
    map (
      e:
      lib.nameValuePair "login-item-${e.name}" {
        serviceConfig = {
          ProgramArguments = [
            "/usr/bin/open"
            "-g" # don't steal focus
            "-a"
            "/Applications/${e.loginItem}.app"
          ];
          RunAtLoad = true;
          LimitLoadToSessionType = "Aqua";
        };
      }
    ) loginItems
  );
}
