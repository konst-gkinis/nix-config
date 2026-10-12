{ pkgs }:

# Extras on top of shared/packages.nix, which default.nix adds.
with pkgs;
[
  # General packages for development and system management
  pinentry_mac
  terminal-notifier
]
