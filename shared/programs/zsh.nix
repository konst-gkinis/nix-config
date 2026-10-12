{
  pkgs,
  lib,
  ...
}:

{
  programs = {
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
          src = lib.cleanSource ../../config;
          file = "p10k.zsh";
        }
      ];

      # Plain shell lives in zsh/init.zsh; only the platform-dependent parts
      # stay here, where they can be generated.
      initContent = lib.mkBefore (
        builtins.readFile ./zsh/init.zsh
        + "\n"
        + ''
          # Reclaim disk space: nix GC, optimise store, brew cleanup.
          cleanup() {
            local nixos_dir="$NH_FLAKE"
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
        ''
      );

      shellAliases = {
        # `ls` is provided by programs.lsd's zsh integration.
        l = "lsd -l --group-directories-first --blocks \"name,date,size\"";
        tree = "lsd --tree --git";
        cat = "bat";
        g = "lazygit";
        # Syntax-aware diffing. Belongs here rather than as a raw `alias` line
        # in initContent so halp can discover it.
        diff = "difft";
        cdi = "zi";
        gstl = "git stash list --format='%gd: %s — %ar'";
        gstam = "git stash push -m '%1'";
      };
    };
  };

  # Descriptions for `halp` (see halp.nix). Adding a command here is optional —
  # halp discovers aliases and functions on its own — so this is prose only.
  # Platform-specific modules add their own entries.
  halp.descriptions = {
    l = "lsd long listing (name, date, size; dirs first)";
    tree = "lsd tree view with git status";
    cat = "bat — syntax-highlighted pager";
    diff = "difft — syntax-aware structural diff";
    g = "lazygit TUI";
    cdi = "zi — interactive zoxide directory picker";
    gstl = "git stash list (readable format)";
    gstam = "git stash push -m <msg>";
    nbs = "nix run .#build-switch, then exec zsh — apply nix config";
    shell = "nix-shell into a nixpkgs package: shell <pkg>";
    ns = "temp zsh with extra packages, keeps prompt: ns <pkg> [pkg …]";
    rg = "ripgrep, rendered by delta (plain rg when piped)";
    nup = "update flake inputs, commit lock, build-switch";
    cleanup = "nix GC + store optimise + brew cleanup";
    halp = "show this help";
    y = "yazi file manager; cd's to the directory it exits in";
    lg = "lazygit; cd's to the directory it exits in";
    z = "zoxide jump: z <part of a path>";
    zi = "zoxide interactive directory picker";
  };
}
