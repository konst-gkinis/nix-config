# `halp` — a self-maintaining cheat sheet for the aliases and functions this
# config defines. Nothing here has to be updated when a command is added:
#
#   * Aliases are taken at build time from `programs.zsh.shellAliases`, the
#     final merged value, so an alias added in any module (shared, darwin, wsl,
#     or by a home-manager module such as lsd) shows up on its own.
#   * Functions are discovered at run time from zsh's `functions_source`, which
#     maps a function name to the file that defined it. Everything defined in
#     the generated .zshrc is ours; plugin and completion functions are not.
#
# The only thing worth keeping by hand is the prose, in `halp.descriptions`
# below — and a command with no entry there still gets listed, an alias with
# its expansion as the description and a function with a blank one.
{
  config,
  lib,
  ...
}:
let
  descriptions = config.halp.descriptions;
  aliases = config.programs.zsh.shellAliases;

  # Alias expansions are full store paths once a home-manager module writes
  # them (`ls` is 60 characters of /nix/store/...-lsd-1.2.0/bin/lsd). Keep just
  # the basename so the fallback description reads as the command it is.
  prettyCommand =
    expansion:
    lib.concatStringsSep " " (
      map (word: if lib.hasPrefix "/nix/store/" word then baseNameOf word else word) (
        lib.splitString " " expansion
      )
    );

  names = lib.attrNames aliases;
  width = lib.foldl' (acc: n: lib.max acc (lib.stringLength n)) 0 names;

  # printf with an escaped %s pair rather than interpolating the text into the
  # format string: descriptions are free-form prose and may contain quotes, %,
  # or backslashes that printf would otherwise interpret.
  aliasLine =
    name:
    "printf '  \\033[1m%-${toString width}s\\033[0m  %s\\n' "
    + "${lib.escapeShellArg name} ${
      lib.escapeShellArg (descriptions.${name} or (prettyCommand aliases.${name}))
    }";

  descPairs = lib.concatStringsSep " " (
    lib.mapAttrsToList (n: d: "${lib.escapeShellArg n} ${lib.escapeShellArg d}") descriptions
  );
in
{
  options.halp.descriptions = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = {
      g = "lazygit TUI";
    };
    description = ''
      One-line descriptions for the aliases and functions `halp` lists, keyed by
      command name. Any module may add entries; a command without one is still
      listed, so this is documentation rather than registration.
    '';
  };

  config.programs.zsh.initContent = ''
    halp() {
      emulate -L zsh
      typeset -A _halp_desc=( ${descPairs} )

      printf '\033[1;33mAliases\033[0m\n'
      ${lib.concatStringsSep "\n  " (map aliasLine (lib.sort (a: b: a < b) names))}

      printf '\n\033[1;33mFunctions\033[0m\n'
      # $zshrc is a symlink into the store and functions_source records the
      # resolved path, so match on both spellings. Names starting with _ are
      # internal helpers (zoxide's __zoxide_*, direnv's _direnv_hook).
      local zshrc=''${ZDOTDIR:-$HOME}/.zshrc
      local f w=0
      local -a found
      for f in ''${(ko)functions_source}; do
        [[ ''${functions_source[$f]} == ($zshrc|''${zshrc:A}) ]] || continue
        [[ $f == _* ]] && continue
        found+=$f
        (( ''${#f} > w )) && w=''${#f}
      done
      for f in $found; do
        printf '  \033[1m%-*s\033[0m  %s\n' $w $f "''${_halp_desc[$f]:-}"
      done
    }
  '';
}
