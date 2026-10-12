{
  ...
}:

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

      # Colors mapped from the Alacritty Ocean/base16 palette below so
      # fzf blends with the terminal theme.
      colors = {
        bg = "#1f2528";
        "bg+" = "#343d46";
        fg = "#c0c5ce";
        "fg+" = "#d8dee9";
        hl = "#6699cc";
        "hl+" = "#5fb3b3";
        info = "#fac863";
        prompt = "#99c794";
        pointer = "#ec5f67";
        marker = "#c594c5";
        spinner = "#c594c5";
        header = "#65737e";
        border = "#65737e";
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
