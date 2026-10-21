# CA roots distrusted on every target. Names are the labels in Mozilla's
# certdata.txt, as nixpkgs' cacert expects. This only covers the Nix CA bundle
# (curl, git, nix itself). On macOS the system keychain (Safari, Chrome, most
# apps) is separate and SIP-protected; distrust its copies by hand with
#   sudo security add-trusted-cert -d -r deny -k /Library/Keychains/System.keychain <cert.pem>
{ ... }:

{
  # eMudhra (emSign) — CA compromised, distrusted pending vendor patches.
  security.pki.caCertificateBlacklist = [
    "emSign Root CA - G1"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
}
