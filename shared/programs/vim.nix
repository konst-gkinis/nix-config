{
  pkgs,
  ...
}:

{
  programs = {
    vim = {
      enable = true;
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
