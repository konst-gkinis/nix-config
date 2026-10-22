{
  lib,
  pkgs,
  ...
}:

let
  palette = import ../palette.nix { inherit lib; };
in
{
  programs = {
    zoxide = {
      enable = true;
      enableBashIntegration = false;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      # Keep the "direnv: loading ..." notice but hide the full env-var
      # diff dump on each load.
      config.global.hide_env_diff = true;
    };

    # Resource monitor. Bundled Ayu theme, 1s refresh, braille graphs.
    btop = {
      enable = true;
      settings = {
        color_theme = "ayu";
        update_ms = 1000;
        graph_symbol = "braille";
        vim_keys = false;
      };
    };

    # Written to a config file referenced via RIPGREP_CONFIG_PATH. Smart
    # case, search dotfiles but skip VCS/build dirs, truncate long lines,
    # Ayu-orange match highlight.
    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "--hidden"
        "--glob=!.git/*"
        "--glob=!node_modules/*"
        "--glob=!.direnv/*"
        "--max-columns=150"
        "--max-columns-preview"
        "--colors=match:fg:${lib.concatMapStringsSep "," toString (palette.rgb palette.orange)}"
        "--colors=match:style:bold"
      ];
    };

    tealdeer = {
      enable = true;
      enableAutoUpdates = true;
    };

    yazi = {
      enable = true;
      shellWrapperName = "y";
      # Soft-wrap long lines in text previews instead of cutting them off.
      settings = {
        preview.wrap = "yes";
        # Enter opens text in bat; $EDITOR stays second in the `O` menu.
        # --paging=always skips less's quit-if-one-screen, which would
        # bounce straight back to yazi on short files.
        opener.view = [
          {
            run = "bat --paging=always %s";
            desc = "bat";
            block = true;
            for = "unix";
          }
        ];
        open.prepend_rules = [
          {
            mime = "text/*";
            use = [
              "view"
              "edit"
              "reveal"
            ];
          }
          {
            mime = "application/{json,ndjson,javascript,wine-extension-ini}";
            use = [
              "view"
              "edit"
              "reveal"
            ];
          }
        ];
      };
      keymap.mgr.prepend_keymap = [
        {
          on = "e";
          run = "shell --block -- \${EDITOR:-vi} %s";
          desc = "Edit selected files in $EDITOR";
        }
      ];
      flavors = {
        ayu-dark = pkgs.fetchFromGitHub {
          owner = "kmlupreti";
          repo = "ayu-dark.yazi";
          rev = "00804daeffe723719a404f72d1c3350751468c61";
          hash = "sha256-uN+ZmczfpYrs1N5oIg/oIjVJJnT29IQE2ALyp6f5pD4=";
        };
      };
      theme = {
        flavor = {
          dark = "ayu-dark";
        };
      };
    };
  };
}
