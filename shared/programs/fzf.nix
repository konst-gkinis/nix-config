{ lib, ... }:

let
  palette = import ../palette.nix { inherit lib; };
in
{
  programs = {
    fzf = {
      enable = true;
      enableZshIntegration = true;

      # Source list for bare `fzf` and the CTRL-T widget: fd is fast,
      # respects .gitignore, includes dotfiles but skips the .git dir.
      defaultCommand = "fd --type f --hidden --exclude .git";

      # Applied to every fzf invocation. Compact bordered pane in the
      # bottom 40% so scrollback stays visible; TAB multi-selects.
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--info=inline"
        "--multi"
      ];

      # Ayu Dark, like the other tools. bg "-1" keeps the terminal's own
      # background, so the pane doesn't show as a box in another theme.
      colors = {
        bg = "-1";
        "bg+" = palette.selection;
        fg = palette.fg;
        "fg+" = palette.white;
        hl = palette.orange;
        "hl+" = palette.orange;
        info = palette.gray;
        prompt = palette.blue;
        pointer = palette.orange;
        marker = palette.green;
        spinner = palette.yellow;
        header = palette.gray;
        border = palette.gutter;
      };

      # CTRL-T: insert a file path. Smart preview — directory listing for
      # dirs, syntax-highlighted file contents otherwise.
      fileWidget = {
        command = "fd --type f --hidden --exclude .git";
        options = [
          "--preview 'if [ -d {} ]; then lsd --tree --color=always {}; else bat --color=always --style=numbers --line-range :500 {}; fi'"
        ];
      };

      # ALT-C: cd into a directory, previewing its tree first.
      changeDirWidget = {
        command = "fd --type d --hidden --exclude .git";
        options = [
          "--preview 'lsd --tree --color=always {} | head -200'"
        ];
      };

      # CTRL-R: search shell history; wrap long commands in a 3-line pane.
      historyWidget = {
        options = [
          "--preview 'echo {}' --preview-window down:3:wrap"
        ];
      };

      # Render the widgets in a centered floating tmux popup (falls back
      # to inline when not inside tmux).
      tmux = {
        enableShellIntegration = true;
        shellIntegrationOptions = [
          "-p"
          "80%,70%"
        ];
      };
    };
  };
}
