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

        # Apply the config, then replace this shell with a fresh one so it
        # picks up the new .zshrc. A function, not an alias: build-switch runs
        # in a child process and cannot exec the shell that started it.
        nbs() {
          nix run .#build-switch -- "$@" && exec zsh
        }

        # Update flake inputs, commit if flake.lock changed, then build-switch.
        # Idempotent: no-ops if flake.lock is already up to date.
        nup() {
          local nixos_dir="$NH_FLAKE"
          (cd "$nixos_dir" && nix flake update || return 1)
          git -C "$nixos_dir" diff --quiet flake.lock && return 0
          git -C "$nixos_dir" add flake.lock && \
          git -C "$nixos_dir" commit -m "chore: update flake inputs" && \
          (cd "$nixos_dir" && nix run .#build-switch) && exec zsh
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

        # ripgrep rendered by delta's grep view. `rg --json` is what delta
        # wants — parsing plain grep output is ambiguous when a match itself
        # contains a colon. rg ignores --json for --files/-l/-c, where delta
        # would render nothing and just append its "this isn't a diff" hint,
        # so those bypass it, as does a non-terminal stdout (scripts, pipes,
        # $(...)). `command rg` skips the wrapper entirely.
        rg() {
          emulate -L zsh
          if [[ ! -t 1 ]]; then
            command rg "$@"
            return
          fi
          local a
          for a in "$@"; do
            case $a in
              --files|--files-with-matches|-l|--count|-c|--count-matches|--json|--help|-h|--version|-V)
                command rg "$@"
                return
                ;;
            esac
          done
          command rg --json "$@" | delta
          return $pipestatus[1]
        }

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
      '';

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
