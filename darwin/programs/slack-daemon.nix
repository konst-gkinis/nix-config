# slack-daemon: every minute, reads your unread Slack messages (DMs and
# channels set to "All new messages", not muted), asks the newest Claude Haiku
# whether you need to react, and sends a 🔴 notification if so. Unread
# messages addressed to you get a 👀 reaction after 2 minutes. Signs in with
# your own Slack web session (no admin-approved app); the Anthropic API key
# and the session live in the login Keychain, never in the Nix store.
# Opt-in at runtime: `sd install` / `sd start`.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  daemon = pkgs.callPackage ./slack-daemon/package.nix { };

  # launchd runs this path, not the store path: it survives rebuilds and GC,
  # and the activation below restarts the daemon when it changes.
  daemonLink = "${config.xdg.dataHome}/slack-daemon/slack-daemond";
  label = "org.nix-config.slack-daemon";

  cli = pkgs.writeShellApplication {
    name = "slack-daemon";
    text = ''
      DAEMON=${lib.escapeShellArg daemonLink}
      ${builtins.readFile ./slack-daemon/slack-daemon.sh}
    '';
  };

  # The wrapper pins terminal-notifier, so notifications don't depend on PATH
  # (launchd agents get a minimal one).
  daemonWrapped = pkgs.writeShellScript "slack-daemond" ''
    export SLACK_DAEMON_NOTIFIER=${pkgs.terminal-notifier}/bin/terminal-notifier
    exec ${daemon}/bin/slack-daemond "$@"
  '';
in
{
  home.packages = [ cli ];
  xdg.dataFile."slack-daemon/slack-daemond".source = daemonWrapped;

  # Unread messages matching any of these (case-insensitive, whole words) get
  # 👀 after `eyes_after_seconds`. '@handle' entries are also resolved to the
  # user group, so its encoded mentions match too.
  xdg.configFile."slack-daemon/config.json".text = builtins.toJSON {
    address_terms = [
      "konstantinos gkinis"
      "@data-platform"
      "@connect-data-dev-team"
      "@devops-team"
      "@engineers"
    ];
    poll_seconds = 60;
    eyes_after_seconds = 120;
  };

  programs.zsh.shellAliases = {
    # Shadows the `sd` find-and-replace tool in interactive shells; reach it
    # with `command sd`.
    sd = "slack-daemon";
  };

  halp.descriptions = {
    slack-daemon = "Slack triage daemon: Haiku picks what needs you (start/stop/install/auth/set-key/…)";
    sd = "slack-daemon (e.g. sd start, sd status, sd auth); the sd tool is `command sd`";
  };

  # A running daemon keeps the old code until restarted.
  home.activation.restartSlackDaemon = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if /bin/launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1; then
      run /bin/launchctl kickstart -k "gui/$(id -u)/${label}"
    fi
  '';
}
