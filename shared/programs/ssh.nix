{ config, ... }:

{
  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "${config.home.homeDirectory}/.ssh/config_external" ];
      settings = {
        "*" = {
          SendEnv = [
            "LANG"
            "LC_*"
          ];
          HashKnownHosts = true;
        };
        # Bare git repos on the homelab Proxmox host; `git backup-init` pushes here.
        # The LAN IP also works away from home through pve's Tailscale subnet route
        # (needs accepted routes: default on macOS, `tailscale up --accept-routes` on Linux).
        pvegit = {
          HostName = "10.0.0.200";
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
          IdentitiesOnly = true;
        };
        # Homelab CT 109: the arr media stack (root-by-key only; see access.md in the homelab repo).
        arr = {
          HostName = "10.0.0.209";
          User = "root";
          IdentityFile = "~/.ssh/id_ed25519";
          IdentitiesOnly = true;
        };
      };
    };
  };
}
