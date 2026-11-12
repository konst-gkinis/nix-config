# Keep SSH key passphrases in the macOS Keychain (Apple's /usr/bin/ssh only;
# Linux openssh rejects UseKeychain, hence darwin-only). A key's passphrase is
# stored once with `ssh-add --apple-use-keychain <key>`.
{ ... }:

{
  programs.ssh.settings."*" = {
    # Read the passphrase from the Keychain instead of prompting...
    UseKeychain = true;
    # ...and load the key into ssh-agent on first use.
    AddKeysToAgent = "yes";
  };

  # Git's SSH commit signing (ssh-keygen -Y sign) reads the key from ssh-agent
  # but never the Keychain, so after a reboot it would prompt until something
  # made an SSH connection. Load every Keychain-stored key at login instead.
  launchd.agents.ssh-add-keychain = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/ssh-add"
        "--apple-load-keychain"
      ];
      RunAtLoad = true;
    };
  };
}
