{
  lib,
  pkgs,
  ...
}:

{
  programs = {
    vim = {
      enable = true;
      # vim-full defaults to a GTK2 GUI on darwin, which fails to build
      # (image.c: no member named 'scale' in 'struct Gui'); terminal vim only.
      packageConfigurable = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
        pkgs.vim-full.override { guiSupport = "none"; }
      );
      plugins = with pkgs.vimPlugins; [
        vim-airline
        vim-airline-themes
        vim-startify
        vim-tmux-navigator
      ];
      settings = {
        ignorecase = true;
      };
      extraConfig = builtins.readFile ./vim/vimrc;
    };
  };
}
