# meeting-daemon: rings an alarm 10 and 5 minutes before each meeting (from
# Calendar.app, plus the Google Calendar API once authorised), opens the Meet
# tab in Brave 2 minutes before, and 1 minute before joins with mic and camera
# off unless you're already in. Opt-in at runtime: `md-install` / `md start`.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  daemon = pkgs.callPackage ./meeting-daemon/package.nix { };

  # launchd runs this path, not the store path: it survives rebuilds and GC,
  # and the activation below restarts the daemon when it changes.
  daemonLink = "${config.xdg.dataHome}/meeting-daemon/meeting-daemond";
  label = "org.nix-config.meeting-daemon";

  # Looped by afplay while an alarm rings. The CLI writes it into the launchd
  # plist (MEETING_DAEMON_SOUND), so changing it needs no rebuild of the daemon
  # binary and so no new Calendar/Automation prompts.
  alarmSound = "/System/Library/Sounds/Hero.aiff";

  cli = pkgs.writeShellApplication {
    name = "meeting-daemon";
    runtimeInputs = [ pkgs.jq ];
    # launchctl, open, … live in /bin and /usr/bin, which home-manager's
    # activation PATH (where restart runs on build-switch) leaves out.
    text = ''
      export PATH="$PATH:/bin:/usr/bin"
      DAEMON=${lib.escapeShellArg daemonLink}
      ALARM_SOUND=${lib.escapeShellArg alarmSound}
      ${builtins.readFile ./meeting-daemon/meeting-daemon.sh}
    '';
  };

  # Brave's per-profile pref behind View → Developer → "Allow JavaScript from
  # Apple Events" (needed to switch mic/camera off and click Join). Brave
  # rewrites Preferences while running, so this only touches it when Brave is
  # closed. Not one of the HMAC-protected prefs, so Brave accepts the edit.
  allowBraveAppleEventsJs = pkgs.writeShellScript "brave-allow-applescript-js" ''
    set -eu
    dir="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
    [ -d "$dir" ] || exit 0
    for prefs in "$dir"/*/Preferences; do
      [ -f "$prefs" ] || continue
      case "$prefs" in */"System Profile"/* | */"Guest Profile"/*) continue ;; esac
      [ "$(${pkgs.jq}/bin/jq '.browser.allow_javascript_apple_events // false' "$prefs")" = true ] && continue
      if /usr/bin/pgrep -xq "Brave Browser"; then
        echo "meeting-daemon: Brave is running, so 'Allow JavaScript from Apple Events' wasn't set." >&2
        echo "  Quit Brave and re-run build-switch, or tick it under View → Developer." >&2
        exit 0
      fi
      ${pkgs.jq}/bin/jq '.browser.allow_javascript_apple_events = true' "$prefs" >"$prefs.meeting-daemon.tmp"
      mv "$prefs.meeting-daemon.tmp" "$prefs"
      echo "meeting-daemon: allowed JavaScript from Apple Events in Brave (''${prefs#"$dir"/})"
    done
  '';
in
{
  home.packages = [
    cli
    (pkgs.writeTextDir "share/zsh/site-functions/_meeting-daemon" (
      builtins.readFile ./meeting-daemon/_meeting-daemon
    ))
  ];
  xdg.dataFile."meeting-daemon/meeting-daemond".source = "${daemon}/bin/meeting-daemond";

  programs.zsh.shellAliases = {
    md = "meeting-daemon";
    md-stop = "meeting-daemon stop";
    md-install = "meeting-daemon install";
    md-uninstall = "meeting-daemon uninstall";
  };

  halp.descriptions = {
    meeting-daemon = "meeting alarm + Meet auto-join daemon (start/stop/install/status/upcoming/…)";
    md = "meeting-daemon (e.g. md start, md status, md silence)";
    md-stop = "stop the meeting daemon (an installed one returns at login)";
    md-install = "run the meeting daemon at every login, starting now";
    md-uninstall = "stop the meeting daemon and remove it from login";
  };

  home.activation.braveAllowAppleEventsJs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${allowBraveAppleEventsJs}
  '';

  # A running daemon keeps the old binary and plist until restarted; restart
  # rewrites the plist, picking up a changed alarmSound.
  home.activation.restartMeetingDaemon = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if /bin/launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1; then
      run ${cli}/bin/meeting-daemon restart
    fi
  '';
}
