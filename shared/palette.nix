# Ayu Dark colours shared by the terminal tools (Alacritty, fzf, lazygit, delta,
# ripgrep, lsd),
# as "#rrggbb". `rgb` converts one to the [ r g b ] triple lsd wants.
{ lib }:

rec {
  bg = "#0b0e14";
  fg = "#bfbdb6";
  white = "#ffffff";
  orange = "#ffb454"; # accent: active borders, file names, matches
  yellow = "#e6b450";
  green = "#aad94c";
  greenLight = "#aad976"; # delta's added-line numbers
  red = "#f07178";
  purple = "#d2a6ff";
  blue = "#59c2ff";
  cyan = "#39bae6";
  teal = "#95e6cb";
  gray = "#6c7380"; # muted text
  gutter = "#565b66"; # borders and rules
  selection = "#2d3640";

  rgb =
    hex:
    map (i: lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex))) [
      0
      2
      4
    ];
}
