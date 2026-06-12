{ pkgs }:

with pkgs;
[
  # General packages for development and system management
  bash-completion
  # bat, btop: installed via home-manager (programs.bat / programs.btop)
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
  jetbrains-mono
  jq
  # ripgrep: installed via home-manager (programs.ripgrep)
  bat-extras.batman
  cheat
  tldr
  tree
  tmux
  unzip
  zsh-powerlevel10k
  # lsd: installed via home-manager (programs.lsd)
  lazydocker
  gdu
  difftastic
  jless
  sd
  gnupg
  pandoc
  less
  moor

  # Development tools
  claude-code
  curl
  gh
  # lazygit: installed via home-manager (programs.lazygit)
  nixfmt
]
