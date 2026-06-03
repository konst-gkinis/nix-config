{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; };
in
shared-packages
++ [
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
