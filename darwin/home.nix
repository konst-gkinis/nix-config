# macOS-only home-manager config. One module per program under ./programs;
# the shared modules are imported by shared/home-manager.nix.
{ pkgs, ... }:

{
  imports = [
    ./programs/iterm2.nix
    ./programs/vscode.nix
    ./programs/pkg-update-check.nix
  ];

  home.stateVersion = "23.11";
  home.packages = [ pkgs.dockutil ];

  # programs.zed-editor = {
  #   enable = true;
  #   extensions = [
  #     "nix"
  #     "terraform"
  #     "catppuccin"
  #     "catppuccin-icons"
  #     "codebook"
  #     "monokai-og"
  #     "ayu-darker"
  #   ];
  # };
}
