{
  pkgs,
  ...
}:

{
  programs = {
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
  };
}
