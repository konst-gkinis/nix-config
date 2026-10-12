{ pkgs }:

# Extras on top of shared/packages.nix, which home.nix adds.
with pkgs;
[
  # Auth
  pinentry-curses

  # Build tools
  gnumake
  cmake
  home-manager

  # Font config
  fontconfig

  # System utilities
  inotify-tools
  libnotify
  sqlite
  xdg-utils
]
