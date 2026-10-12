{
  pkgs,
  ...
}:

{
  programs = {
    tmux = {
      enable = true;
      plugins = with pkgs.tmuxPlugins; [
        vim-tmux-navigator
        sensible
        yank
        prefix-highlight
        {
          plugin = power-theme;
          extraConfig = ''
            set -g @tmux_power_theme 'gold'
          '';
        }
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-dir '$HOME/.cache/tmux/resurrect'
            set -g @resurrect-capture-pane-contents 'on'
            set -g @resurrect-pane-contents-area 'visible'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '5' # minutes
          '';
        }
      ];
      terminal = "screen-256color";
      prefix = "C-x";
      escapeTime = 10;
      historyLimit = 50000;
      extraConfig = builtins.readFile ./tmux/tmux.conf;
    };
  };
}
