# Home-manager config shared by every target. One module per program (or
# small group of programs) under ./programs.
{ ... }:

{
  imports = [
    ./halp.nix
    ./programs/claude.nix
    ./programs/shell-tools.nix
    ./programs/lazygit.nix
    ./programs/bat.nix
    ./programs/fzf.nix
    ./programs/lsd.nix
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/vim.nix
    ./programs/alacritty.nix
    ./programs/ssh.nix
    ./programs/tmux.nix
  ];
}
