{ pkgs }:

with pkgs;
[
  # General packages for development and system management
  bash-completion
  bat
  btop
  coreutils

  # Media-related packages
  dejavu_fonts
  fd
  font-awesome
  hack-font
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf

  # Node.js development tools
  nodejs_24

  # Text and terminal utilities
  fastfetch
  htop
  jetbrains-mono
  jq
  ripgrep
  cheat
  tldr
  tree
  tmux
  unzip
  zsh-powerlevel10k
  lsd
  lazydocker
  gdu
  difftastic
  jless
  sd
  gnupg
  pandoc

  # Development tools
  claude-code
  curl
  gh
  lazygit
  fzf
  nixfmt
]
