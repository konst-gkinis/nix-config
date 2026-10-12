{
  ...
}:

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
      # Ayu Dark palette (RGB triples) for the metadata columns. Setting
      # `colors` makes the module switch color.theme to "custom".
      colors = {
        user = [
          255
          180
          84
        ];
        group = [
          230
          180
          80
        ];
        permission = {
          read = [
            170
            217
            76
          ];
          write = [
            230
            180
            80
          ];
          exec = [
            240
            113
            120
          ];
          "exec-sticky" = [
            210
            166
            255
          ];
          "no-access" = [
            108
            115
            128
          ];
          octal = [
            57
            186
            230
          ];
          acl = [
            89
            194
            255
          ];
          context = [
            108
            115
            128
          ];
        };
        date = {
          "hour-old" = [
            170
            217
            76
          ];
          "day-old" = [
            230
            180
            80
          ];
          older = [
            108
            115
            128
          ];
        };
        size = {
          none = [
            108
            115
            128
          ];
          small = [
            170
            217
            76
          ];
          medium = [
            230
            180
            80
          ];
          large = [
            255
            180
            84
          ];
        };
        inode = {
          valid = [
            191
            189
            182
          ];
          invalid = [
            108
            115
            128
          ];
        };
        links = {
          valid = [
            89
            194
            255
          ];
          invalid = [
            108
            115
            128
          ];
        };
        "tree-edge" = [
          108
          115
          128
        ];
      };
    };
  };
}
