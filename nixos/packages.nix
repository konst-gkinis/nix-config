{ pkgs }:

# Extras on top of shared/packages.nix, which home.nix adds.
with pkgs;
[

  # Security and authentication
  yubikey-agent
  pinentry-curses

  # App and package management
  appimage-run
  gnumake
  cmake
  home-manager

  # Media and design tools
  fontconfig

  # Productivity tools

  # Audio tools
  pavucontrol # Pulse audio controls

  # Testing and development tools
  rofi
  rofi-calc

  # Screenshot and recording tools
  flameshot

  # Text and terminal utilities
  unixtools.ifconfig
  unixtools.netstat
  xwininfo # Provides a cursor to click and learn about windows
  xrandr

  # File and system utilities
  inotify-tools # inotifywait, inotifywatch - For file system events
  libnotify
  pcmanfm # File browser
  sqlite
  xdg-utils

  # Other utilities
  google-chrome

  # PDF viewer
  zathura

  # Development tools
  firefox

  # Music and entertainment
]
