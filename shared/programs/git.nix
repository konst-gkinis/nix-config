{
  config,
  lib,
  fullName,
  email,
  workGitDir ? null,
  ...
}:

{
  programs = {
    # Pager for git diff/log/show/blame and for interactive staging. Ayu
    # colours to match bat/lazygit; the syntax theme is bat's (delta reads
    # bat's built asset cache, so the custom ayu-dark theme above applies).
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true; # n / N jump between files in the pager
        line-numbers = true;
        side-by-side = true;
        # Styling for delta's grep view (git grep / the rg wrapper below).
        grep-file-style = "bold #ffb454";
        grep-line-number-style = "#59c2ff";
        syntax-theme = "ayu-dark";
        file-style = "bold #ffb454";
        file-decoration-style = "#565b66 ul";
        hunk-header-decoration-style = "#565b66 box";
        line-numbers-minus-style = "#f07178";
        line-numbers-plus-style = "#aad976";
        line-numbers-zero-style = "#565b66";
      };
    };

    # Syntax-aware merge driver: resolves conflicts that are only textual
    # (adjacent imports, list entries, functions) during merge/rebase/cherry-pick,
    # so lazygit never shows them. The module adds the driver and a
    # `* merge=mergiraf` attribute; unsupported file types fall back to git's merge.
    mergiraf = {
      enable = true;
      enableGitIntegration = true;
    };

    git = {
      enable = true;
      ignores = [
        "*.swp"
        ".DS_Store"
        ".idea/"
        "**/.claude/settings.local.json"
        "**/.claude/.cc-writes/"
      ];
      lfs = {
        enable = true;
      };
      # Second GitHub identity: for repos under `workGitDir`, git additionally
      # reads "<workGitDir>.gitconfig". Only the pointer lives here — the work
      # name/email/signing key stay in that plain file, editable without a
      # rebuild. home-manager emits includes with mkAfter, so this lands after
      # the global user.* below and wins.
      includes = lib.optionals (workGitDir != null) (
        # The trailing slash is load-bearing: "gitdir:~/foo" matches only a repo
        # at exactly that path, while "gitdir:~/foo/" gets an implicit "**" and
        # matches everything beneath it. Normalise so either spelling works.
        let
          dir = (lib.removeSuffix "/" workGitDir) + "/";
        in
        [
          {
            condition = "gitdir:${dir}";
            path = "${dir}.gitconfig";
          }
        ]
      );
      signing = {
        key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
        format = "ssh";
        signByDefault = true;
      };
      settings = {
        user.name = fullName;
        user.email = email;
        branch.sort = "committerdate";
        # Distinguishes moved lines from added/removed ones; delta renders it.
        diff.colorMoved = "default";
        # delta renders `git grep` too. It needs the line numbers in the
        # output to parse it, and git only emits them with grep.lineNumber.
        pager.grep = "delta";
        grep.lineNumber = true;
        # mergiraf's module sets diff3; zdiff3 is diff3 with the common
        # prefix/suffix lines pulled out of the hunk, which mergiraf also parses.
        merge.conflictStyle = lib.mkForce "zdiff3";
        # Conflicts mergiraf can't solve: VS Code's 3-way merge editor, which
        # lazygit opens with `M`. --wait blocks until the tab is closed.
        merge.tool = "code";
        mergetool.code.cmd = ''code --wait --merge "$REMOTE" "$LOCAL" "$BASE" "$MERGED"'';
        mergetool.keepBackup = false;
        # Record conflict resolutions and replay them (and stage the result)
        # when the same conflict comes back, e.g. on a repeated rebase.
        rerere.enabled = true;
        rerere.autoUpdate = true;
        init.defaultBranch = "main";
        core = {
          editor = "vim";
          autocrlf = "input";
        };
        # The file itself is generated per-machine by
        # scripts/setup-signature-verification.sh; only the pointer is declarative.
        gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
        pull.rebase = true;
        push.autoSetupRemote = true;
        rebase.autoStash = true;
      };
    };
  };
}
