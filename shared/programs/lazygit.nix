{
  ...
}:

{
  programs = {
    # `g` alias (see shellAliases). Nerd-font icons, file tree, command
    # log hidden, and an Ayu accent theme. Editor left to auto-detect
    # ($EDITOR/$VISUAL), so no editPreset.
    lazygit = {
      enable = true;
      settings = {
        git = {
          overrideGpg = true;
          # lazygit ignores git's core.pager, so delta has to be named again
          # here (the pre-0.65 `paging` key is gone; lazygit can't migrate the
          # config itself because it's a read-only nix store symlink).
          # --paging=never because lazygit does its own scrolling; delta still
          # reads its [delta] section from ~/.config/git/config. The hyperlinks
          # format makes file/line links open in lazygit's editor.
          diffRenderers = [
            {
              command = ''delta --dark --paging=never --hyperlinks --hyperlinks-file-link-format="lazygit-edit://{path}:{line}"'';
            }
          ];
        };
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
  };
}
