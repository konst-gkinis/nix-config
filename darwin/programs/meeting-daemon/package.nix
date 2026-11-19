# meeting-daemond: the Swift binary launchd runs. Built with plain swiftc
# (no SwiftPM); the Core tests run in checkPhase.
{ lib, swiftPackages, swift }:

swiftPackages.stdenv.mkDerivation {
  pname = "meeting-daemond";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Sources ./Tests ./Info.plist ];
  };

  nativeBuildInputs = [ swift ];

  # The embedded Info.plist carries the usage strings macOS needs before it
  # will prompt for Calendar / Automation access on the binary's behalf.
  buildPhase = ''
    runHook preBuild
    swiftc -O -swift-version 5 -module-name MeetingDaemon \
      Sources/Core/*.swift Sources/App/*.swift \
      -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist \
      -o meeting-daemond
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    swiftc -swift-version 5 -module-name MeetingTests Sources/Core/*.swift Tests/*.swift -o core-tests
    ./core-tests
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 meeting-daemond $out/bin/meeting-daemond
    runHook postInstall
  '';

  meta.platforms = lib.platforms.darwin;
}
