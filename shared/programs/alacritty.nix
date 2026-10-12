{
  pkgs,
  lib,
  ...
}:

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

        colors = {
          primary = {
            background = "0x1f2528";
            foreground = "0xc0c5ce";
          };

          normal = {
            black = "0x1f2528";
            red = "0xec5f67";
            green = "0x99c794";
            yellow = "0xfac863";
            blue = "0x6699cc";
            magenta = "0xc594c5";
            cyan = "0x5fb3b3";
            white = "0xc0c5ce";
          };

          bright = {
            black = "0x65737e";
            red = "0xec5f67";
            green = "0x99c794";
            yellow = "0xfac863";
            blue = "0x6699cc";
            magenta = "0xc594c5";
            cyan = "0x5fb3b3";
            white = "0xd8dee9";
          };
        };
      };
    };
  };
}
