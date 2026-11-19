# Tab completion for this config's own commands: nadd, ns, nbs and
# git backup-init / backup-clone. Each is a `_<command>` file in
# ./zsh-completions, put on fpath through the profile's
# share/zsh/site-functions. A module that adds a command of its own
# ships its completion with it (darwin/programs/meeting-daemon.nix).
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.runCommandLocal "nix-config-zsh-completions" { } ''
      mkdir -p $out/share/zsh/site-functions
      cp ${./zsh-completions}/_* $out/share/zsh/site-functions/
    '')
  ];

  # zsh's own _hosts also claims `ns` (the nameserver tool) and wins on fpath
  # order, so bind ours once oh-my-zsh has run compinit (default order runs after).
  programs.zsh.initContent = "compdef _ns ns";
}
