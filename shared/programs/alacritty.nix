{
  pkgs,
  lib,
  ...
}:

let
  palette = import ../palette.nix { inherit lib; };
in
{
  programs = {
    alacritty = {
      enable = true;
      settings = {
        cursor = {
          style = "Block";
        };

        window = {
          opacity = 1.0;
          padding = {
            x = 24;
            y = 24;
          };
          dimensions = {
            columns = 80;
            lines = 30;
          };
        };

        terminal.shell = {
          program = "${pkgs.zsh}/bin/zsh";
        };

        font = {
          normal = {
            family = "MesloLGS NF";
            style = "Regular";
          };
          size = lib.mkMerge [
            (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 10)
            (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 18)
          ];
        };

        # Ayu Dark. Bright variants repeat the normal ones except black and
        # white, as in Ayu's own terminal themes.
        colors = {
          primary = {
            background = palette.bg;
            foreground = palette.fg;
          };

          normal = {
            black = palette.bg;
            red = palette.red;
            green = palette.green;
            yellow = palette.yellow;
            blue = palette.blue;
            magenta = palette.purple;
            cyan = palette.teal;
            white = palette.fg;
          };

          bright = {
            black = palette.gray;
            red = palette.red;
            green = palette.green;
            yellow = palette.orange;
            blue = palette.blue;
            magenta = palette.purple;
            cyan = palette.teal;
            white = palette.white;
          };
        };
      };
    };
  };
}
