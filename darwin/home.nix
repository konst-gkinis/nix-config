{ ... }:

let
  mkColor = r: g: b: {
    "Color Space" = "sRGB";
    "Red Component" = r;
    "Green Component" = g;
    "Blue Component" = b;
    "Alpha Component" = 1.0;
  };
in
{
  targets.darwin.defaults."com.googlecode.iterm2"."Default Bookmark Guid" = "ayu-mirage";

  home.file."Library/Application Support/iTerm2/DynamicProfiles/ayu-mirage.json".text =
    builtins.toJSON {
      Profiles = [
        {
          Name = "Ayu Mirage";
          Guid = "ayu-mirage";

          "Background Color" = mkColor 0.1216 0.1412 0.1882;
          "Foreground Color" = mkColor 0.7961 0.8000 0.7765;
          "Cursor Color" = mkColor 1.0 0.8000 0.4000;
          "Cursor Text Color" = mkColor 0.1216 0.1412 0.1882;
          "Selection Color" = mkColor 0.2039 0.2706 0.3529;
          "Selected Text Color" = mkColor 0.7961 0.8000 0.7765;
          "Bold Color" = mkColor 0.7961 0.8000 0.7765;

          "Ansi 0 Color" = mkColor 0.0980 0.1176 0.1647; # Black      #191E2A
          "Ansi 1 Color" = mkColor 0.9490 0.5294 0.4745; # Red        #F28779
          "Ansi 2 Color" = mkColor 0.7294 0.9020 0.4941; # Green      #BAE67E
          "Ansi 3 Color" = mkColor 1.0 0.8196 0.4510; # Yellow     #FFD173
          "Ansi 4 Color" = mkColor 0.4510 0.8157 1.0; # Blue       #73D0FF
          "Ansi 5 Color" = mkColor 0.8314 0.7490 1.0; # Magenta    #D4BFFF
          "Ansi 6 Color" = mkColor 0.5843 0.9020 0.7961; # Cyan       #95E6CB
          "Ansi 7 Color" = mkColor 0.7804 0.7804 0.7804; # White      #C7C7C7
          "Ansi 8 Color" = mkColor 0.4078 0.4078 0.4078; # Br Black   #686868
          "Ansi 9 Color" = mkColor 0.9490 0.5294 0.4745; # Br Red
          "Ansi 10 Color" = mkColor 0.7294 0.9020 0.4941; # Br Green
          "Ansi 11 Color" = mkColor 1.0 0.8196 0.4510; # Br Yellow
          "Ansi 12 Color" = mkColor 0.4510 0.8157 1.0; # Br Blue
          "Ansi 13 Color" = mkColor 0.8314 0.7490 1.0; # Br Magenta
          "Ansi 14 Color" = mkColor 0.5843 0.9020 0.7961; # Br Cyan
          "Ansi 15 Color" = mkColor 1.0 1.0 1.0; # Br White   #FFFFFF
        }
      ];
    };
}
