# Spotlight doesn't index the symlinks home-manager puts in
# ~/Applications/Home Manager Apps, so mirror them as Finder aliases.
{
  pkgs,
  lib,
  user,
  ...
}:

{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Creating Spotlight-indexable aliases for Home Manager apps..." >&2
    hm_apps="/Users/${user}/Applications/Home Manager Apps"
    wrappers="/Users/${user}/Applications/Home Manager App Wrappers"
    rm -rf "$wrappers"
    mkdir -p "$wrappers"
    if [ -d "$hm_apps" ]; then
      find "$hm_apps" -maxdepth 1 -name "*.app" | while read -r app; do
        ${pkgs.mkalias}/bin/mkalias "$app" "$wrappers/$(basename "$app")"
      done
    fi
  '';
}
