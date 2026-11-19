# slack-daemon: every minute, reads your unread Slack messages (DMs and
# channels set to "All new messages", not muted), asks the newest Claude Haiku
# whether you need to react, and sends a 🔴 notification if so. Unread
# messages addressed to you get a random 👀 👍 👌 ✅ 👁️ reaction after 2 minutes. Signs in with
# your own Slack web session (no admin-approved app), kept in the login
# Keychain, never in the Nix store. Claude is called with the `ant` CLI's OAuth
# login (`slackd ant-login`), not an API key.
# Opt-in at runtime: `slackd install` / `slackd start`.
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
  # (launchd agents get a minimal one). `ant` is a Homebrew cask
  # (darwin/casks.nix), so its prefix goes on PATH (Apple silicon, then Intel).
  daemonWrapped = pkgs.writeShellScript "slack-daemond" ''
    export SLACK_DAEMON_NOTIFIER=${pkgs.terminal-notifier}/bin/terminal-notifier
    export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
    exec ${daemon}/bin/slack-daemond "$@"
  '';
in
{
  home.packages = [ cli ];
  xdg.dataFile."slack-daemon/slack-daemond".source = daemonWrapped;

  # Unread messages matching any of these (case-insensitive, whole words) get
  # a reaction after `ack_after_seconds`. '@handle' entries are also resolved to the
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
    ack_after_seconds = 120;
  };

  programs.zsh.shellAliases = {
    slackd = "slack-daemon";
  };

  halp.descriptions = {
    slack-daemon = "Slack triage daemon: Haiku picks what needs you (start/stop/install/auth/ant-login/…)";
    slackd = "slack-daemon (e.g. slackd start, slackd status, slackd auth)";
  };

  # A running daemon keeps the old code until restarted.
  home.activation.restartSlackDaemon = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if /bin/launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1; then
      run /bin/launchctl kickstart -k "gui/$(id -u)/${label}"
    fi
  '';
}
