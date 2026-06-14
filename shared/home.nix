{
  config,
  pkgs,
  lib,
  user,
  fullName ? "Konstantinos Gkinis",
  email ? "konst.gkinis@gmail.com",
  ...
}:
{
  home.file = {
    ".claude/CLAUDE.md".source = ../claude/CLAUDE.md;
    ".claude/settings.json".source = ../claude/settings.json;
    ".claude/statusline-command.sh" = {
      source = ../claude/statusline-command.sh;
      executable = true;
    };
    ".claude/themes/ayu-dark.json".source = ../claude/themes/ayu-dark.json;
  };

  programs = {
    zoxide = {
      enable = true;
      enableBashIntegration = false;
    };

    # `g` alias (see shellAliases). Nerd-font icons, file tree, command
    # log hidden, and an Ayu accent theme. Editor left to auto-detect
    # ($EDITOR/$VISUAL), so no editPreset.
    lazygit = {
      enable = true;
      settings = {
        gui = {
          nerdFontsVersion = "3";
          showFileTree = true;
          showCommandLog = false;
          theme = {
            activeBorderColor = [
              "#ffb454"
              "bold"
            ];
            inactiveBorderColor = [ "#565b66" ];
            optionsTextColor = [ "#59c2ff" ];
            selectedLineBgColor = [ "#2d3640" ];
            cherryPickedCommitBgColor = [ "#2d3640" ];
            cherryPickedCommitFgColor = [ "#ffb454" ];
            unstagedChangesColor = [ "#f07178" ];
            defaultFgColor = [ "#bfbdb6" ];
          };
        };
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      # Keep the "direnv: loading ..." notice but hide the full env-var
      # diff dump on each load.
      config.global.hide_env_diff = true;
    };

    # Aliased to `cat` (see shellAliases). Ayu Dark theme + line numbers
    # and git change markers; pages long output through less.
    bat = {
      enable = true;
      config = {
        theme = "ayu-dark";
        style = "numbers,changes";
        paging = "auto";
      };
      # bat only reads .tmTheme (XML) themes; current dempfi/ayu ships the
      # newer .sublime-color-scheme format, so pin the last commit that
      # still had the .tmTheme files. home-manager runs `bat cache --build`.
      themes = {
        ayu-dark = {
          src = pkgs.fetchFromGitHub {
            owner = "dempfi";
            repo = "ayu";
            rev = "d7c307c5024b56909c9b9259f54e88ff9cb931bd";
            hash = "sha256-O0zoKAmCgSAHv2gcORYrorIlw0kdXN1+2k2Emtntc2g=";
          };
          file = "ayu-dark.tmTheme";
        };
      };
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
        "--colors=match:fg:255,180,84"
        "--colors=match:style:bold"
      ];
    };

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
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      fileWidgetOptions = [
        "--preview 'if [ -d {} ]; then lsd --tree --color=always {}; else bat --color=always --style=numbers --line-range :500 {}; fi'"
      ];

      # ALT-C: cd into a directory, previewing its tree first.
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
      changeDirWidgetOptions = [
        "--preview 'lsd --tree --color=always {} | head -200'"
      ];

      # CTRL-R: search shell history; wrap long commands in a 3-line pane.
      historyWidgetOptions = [
        "--preview 'echo {}' --preview-window down:3:wrap"
      ];

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

    yazi = {
      enable = true;
      shellWrapperName = "y";
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
    zsh = {
      enable = true;
      autocd = true;
      oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [
          "git"
          "colored-man-pages"
        ];
      };
      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = lib.cleanSource ../config;
          file = "p10k.zsh";
        }
      ];

      initContent = lib.mkBefore ''
        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
          . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
          . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
        fi

        # Force a valid UNIX locale (macOS region en_DK has no UNIX locale,
        # which makes iTerm2 and CLI tools complain)
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8

        # Define variables for directories
        export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
        export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
        export PATH=$HOME/.local/share/bin:$PATH

        # Remove history data we don't want to see
        export HISTIGNORE="pwd:ls:cd"

        # nix shortcuts
        shell() {
            nix-shell '<nixpkgs>' -A "$1"
        }

        # Update flake inputs, commit if flake.lock changed, then build-switch.
        # Idempotent: no-ops if flake.lock is already up to date.
        nup() {
          local nixos_dir="$HOME/nixos-config"
          (cd "$nixos_dir" && nix flake update || return 1)
          git -C "$nixos_dir" diff --quiet flake.lock && return 0
          git -C "$nixos_dir" add flake.lock && \
          git -C "$nixos_dir" commit -m "chore: update flake inputs" && \
          (cd "$nixos_dir" && nix run .#build-switch)
        }

        # Temporary shell with extra packages, keeping zsh + p10k visible.
        # The flakes `nix shell` doesn't set $IN_NIX_SHELL, so the p10k
        # nix_shell segment never lights up (classic `nix-shell -p` does set
        # it). We set it ourselves; `nix shell` inherits it into the inner
        # zsh, so the segment shows. Bare names resolve to nixpkgs#<name>;
        # refs containing `#` or `:` pass through (e.g. `ns nixpkgs#hello`).
        ns() {
          emulate -L zsh
          local -a refs
          local p
          for p in "$@"; do
            if [[ $p == *[#:]* ]]; then refs+=("$p"); else refs+=("nixpkgs#$p"); fi
          done
          IN_NIX_SHELL=impure nix shell "''${refs[@]}" --command zsh -i
        }

        # Use difftastic, syntax-aware diffing
        alias diff=difft

        # Reclaim disk space: nix GC, optimise store, brew cleanup.
        cleanup() {
          local nixos_dir="$HOME/nixos-config"
          printf '\033[1;33m→ nix store GC\033[0m\n'
          (cd "$nixos_dir" && nix run .#clean) || return 1
          printf '\033[1;33m→ nix store optimise\033[0m\n'
          nix store optimise
          ${
            if pkgs.stdenv.hostPlatform.isDarwin then
              ''
                printf '\033[1;33m→ brew cleanup\033[0m\n'
                brew cleanup
              ''
            else
              ""
          }
        }

        halp() {
          printf '\033[1;33mAliases\033[0m\n'
          printf '  \033[1ml\033[0m       lsd long listing (name, date, size; dirs first)\n'
          printf '  \033[1mtree\033[0m    lsd tree view with git status\n'
          printf '  \033[1mcat\033[0m     bat — syntax-highlighted pager\n'
          printf '  \033[1mdiff\033[0m    difft — syntax-aware structural diff\n'
          printf '  \033[1mg\033[0m       lazygit TUI\n'
          printf '  \033[1mcdi\033[0m     zi — interactive zoxide directory picker\n'
          printf '  \033[1mgstl\033[0m    git stash list (readable format)\n'
          printf '  \033[1mgstam\033[0m   git stash push -m <msg>\n'
          printf '  \033[1mnbs\033[0m     nix run .#build-switch — apply nix config\n'
          printf '\n\033[1;33mFunctions\033[0m\n'
          printf '  \033[1mshell\033[0m <pkg>          nix-shell into a nixpkgs package\n'
          printf '  \033[1mns\033[0m <pkg> [pkg …]     temp zsh with extra packages (keeps prompt)\n'
          printf '  \033[1mnup\033[0m                  update flake inputs, commit lock, build-switch\n'
          printf '  \033[1mcleanup\033[0m              nix GC + store optimise + brew cleanup\n'
          printf '  \033[1mhalp\033[0m                 show this help\n'
        }

        # Add SSH keys to agent on login
        ${
          if pkgs.stdenv.hostPlatform.isDarwin then
            ''
              ssh-add --apple-load-keychain -q 2>/dev/null || true
            ''
          else
            ''
              ssh-add -q 2>/dev/null || true
            ''
        }
      '';

      shellAliases = {
        # `ls` is provided by programs.lsd's zsh integration.
        l = "lsd -l --group-directories-first --blocks \"name,date,size\"";
        tree = "lsd --tree --git";
        cat = "bat";
        g = "lazygit";
        nbs = "nix run .#build-switch";
        cdi = "zi";
        gstl = "git stash list --format='%gd: %s — %ar'";
        gstam = "git stash push -m '%1'";
      };
    };

    tealdeer = {
      enable = true;
      enableAutoUpdates = true;
    };

    git = {
      enable = true;
      ignores = [ "*.swp" ];
      lfs = {
        enable = true;
      };
      signing = {
        key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
        format = "ssh";
        signByDefault = true;
      };
      settings = {
        user.name = fullName;
        user.email = email;
        init.defaultBranch = "main";
        core = {
          editor = "vim";
          autocrlf = "input";
        };
        pull.rebase = true;
        push.autoSetupRemote = true;
        rebase.autoStash = true;
      };
    };

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
      extraConfig = ''
        "" General
        set number
        set history=1000
        set nocompatible
        set modelines=0
        set encoding=utf-8
        set scrolloff=3
        set showmode
        set showcmd
        set hidden
        set wildmenu
        set wildmode=list:longest
        set cursorline
        set ttyfast
        set nowrap
        set ruler
        set backspace=indent,eol,start
        set laststatus=2
        set clipboard=autoselect

        " Dir stuff
        set nobackup
        set nowritebackup
        set noswapfile
        set backupdir=~/.config/vim/backups
        set directory=~/.config/vim/swap

        " Relative line numbers for easy movement
        set relativenumber
        set rnu

        "" Whitespace rules
        set tabstop=8
        set shiftwidth=2
        set softtabstop=2
        set expandtab

        "" Searching
        set incsearch
        set gdefault

        "" Statusbar
        set nocompatible " Disable vi-compatibility
        set laststatus=2 " Always show the statusline
        let g:airline_theme='bubblegum'
        let g:airline_powerline_fonts = 1

        "" Local keys and such
        let mapleader=","
        let maplocalleader=" "

        "" Change cursor on mode
        :autocmd InsertEnter * set cul
        :autocmd InsertLeave * set nocul

        "" File-type highlighting and configuration
        syntax on
        filetype on
        filetype plugin on
        filetype indent on

        "" Paste from clipboard
        nnoremap <Leader>, "+gP

        "" Copy from clipboard
        xnoremap <Leader>. "+y

        "" Move cursor by display lines when wrapping
        nnoremap j gj
        nnoremap k gk

        "" Map leader-q to quit out of window
        nnoremap <leader>q :q<cr>

        "" Move around split
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l

        "" Easier to yank entire line
        nnoremap Y y$

        "" Move buffers
        nnoremap <tab> :bnext<cr>
        nnoremap <S-tab> :bprev<cr>

        "" Like a boss, sudo AFTER opening the file to write
        cmap w!! w !sudo tee % >/dev/null

        let g:startify_lists = [
          \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
          \ { 'type': 'sessions',  'header': ['   Sessions']       },
          \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      }
          \ ]

        let g:startify_bookmarks = [
          \ '~/Projects',
          \ '~/Documents',
          \ ]

        let g:airline_theme='bubblegum'
        let g:airline_powerline_fonts = 1
      '';
    };

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

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${user}/.ssh/config_external")
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.ssh/config_external")
      ];
      settings = {
        "*" = {
          SendEnv = [
            "LANG"
            "LC_*"
          ];
          HashKnownHosts = true;
        };
      };
    };

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
      extraConfig = ''
        # Remove Vim mode delays
        set -g focus-events on

        # Enable full mouse support
        set -g mouse on

        # -----------------------------------------------------------------------------
        # Key bindings
        # -----------------------------------------------------------------------------

        # Unbind default keys
        unbind C-b
        unbind '"'
        unbind %

        # Split panes, vertical or horizontal
        bind-key x split-window -v
        bind-key v split-window -h

        # Move around panes with vim-like bindings (h,j,k,l)
        bind-key -n M-k select-pane -U
        bind-key -n M-h select-pane -L
        bind-key -n M-j select-pane -D
        bind-key -n M-l select-pane -R

        # Smart pane switching with awareness of Vim splits.
        # This is copy paste from https://github.com/christoomey/vim-tmux-navigator
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
          | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
        bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
        bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
        bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
        tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
        if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
          "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
        if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
          "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R
        bind-key -T copy-mode-vi 'C-\' select-pane -l
      '';
    };
  };
}
