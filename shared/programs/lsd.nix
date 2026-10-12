{
  lib,
  ...
}:

let
  palette = import ../palette.nix { inherit lib; };
  inherit (palette) rgb;
in
{
  programs = {
    # Provides ls/ll/la/lt/lla/llt aliases via zsh integration. The custom
    # `ls` alias was removed from shellAliases to avoid clashing; `l` and
    # `tree` remain (lsd doesn't define those).
    lsd = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        icons = {
          when = "auto";
          theme = "fancy";
        };
        date = "relative";
        sorting = {
          column = "name";
          "dir-grouping" = "first";
        };
      };
      # Ayu Dark palette for the metadata columns. Setting
      # `colors` makes the module switch color.theme to "custom".
      colors = {
        user = rgb palette.orange;
        group = rgb palette.yellow;
        permission = {
          read = rgb palette.green;
          write = rgb palette.yellow;
          exec = rgb palette.red;
          "exec-sticky" = rgb palette.purple;
          "no-access" = rgb palette.gray;
          octal = rgb palette.cyan;
          acl = rgb palette.blue;
          context = rgb palette.gray;
        };
        date = {
          "hour-old" = rgb palette.green;
          "day-old" = rgb palette.yellow;
          older = rgb palette.gray;
        };
        size = {
          none = rgb palette.gray;
          small = rgb palette.green;
          medium = rgb palette.yellow;
          large = rgb palette.orange;
        };
        inode = {
          valid = rgb palette.fg;
          invalid = rgb palette.gray;
        };
        links = {
          valid = rgb palette.blue;
          invalid = rgb palette.gray;
        };
        "tree-edge" = rgb palette.gray;
      };
    };
  };
}
