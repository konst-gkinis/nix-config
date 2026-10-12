# home-manager wiring common to every target: each target's default.nix only
# adds its own home.nix and platform-specific home-manager options.
{
  user,
  fullName,
  email,
  workGitDir ? null,
  flakeDir,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = {
      inherit
        user
        fullName
        email
        workGitDir
        flakeDir
        ;
    };
    users.${user} = {
      imports = [ ./home.nix ];
      home.enableNixpkgsReleaseCheck = false;
    };
  };
}
