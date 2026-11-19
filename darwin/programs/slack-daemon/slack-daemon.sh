# slack-daemon: manage the Slack triage daemon (launchd) and pass the rest
# through to slack-daemond. DAEMON (the stable symlink launchd runs) is
# defined above this file by darwin/programs/slack-daemon.nix.

LABEL=org.nix-config.slack-daemon
DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"
AGENT_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# `start` without `install` loads a plist from here: launchd doesn't read this
# directory at login, so the daemon runs until logout / `stop` only.
SESSION_PLIST="${XDG_STATE_HOME:-$HOME/.local/state}/slack-daemon/$LABEL.plist"
LOG="$HOME/Library/Logs/slack-daemon.log"

usage() {
  cat <<EOF
usage: slack-daemon <command>   (alias: slackd <command>)

  install     run at every login from now on, and start now   (slackd install)
  uninstall   stop and no longer run at login                 (slackd uninstall)
  start       start now (until logout if not installed)       (slackd start)
  stop        stop now; an installed daemon returns at login  (slackd stop)
  restart     stop and start
  status      whether it is installed / running, and the last log lines
  logs        follow the log ($LOG)

  auth        sign in to Slack in a throwaway browser window
  logout      forget the Slack session
  ant-login   sign in to Anthropic with the ant CLI (ant auth login)
  check       test the Slack session and the ant login
  channels    conversations with unread messages, and how each is handled
  once        run one poll in the foreground
  test-notify show a sample notification
EOF
}

is_loaded() { launchctl print "$SERVICE" >/dev/null 2>&1; }

write_plist() {
  mkdir -p "$(dirname "$1")" "$(dirname "$LOG")"
  cat >"$1" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$DAEMON</string><string>run</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
}

unload() {
  is_loaded || return 0
  launchctl bootout "$SERVICE" 2>/dev/null || true
  # bootout returns before the job is gone; bootstrap would fail until it is.
  for _ in $(seq 50); do is_loaded || return 0; sleep 0.1; done
}

load() {
  unload
  launchctl bootstrap "$DOMAIN" "$1"
}

start() {
  if is_loaded; then
    launchctl kickstart "$SERVICE"
  elif [ -f "$AGENT_PLIST" ]; then
    load "$AGENT_PLIST"
  else
    write_plist "$SESSION_PLIST"
    load "$SESSION_PLIST"
  fi
  echo "slack-daemon started (log: $LOG)"
}

ant_login() {
  # The daemon's wrapper (which `check` runs) finds ant in the Homebrew prefix.
  command -v ant >/dev/null || { echo "ant not found; it's the anthropics/tap/ant cask in darwin/casks.nix" >&2; return 1; }
  ant auth login
  echo "The daemon asks ant for a fresh token on every call: no restart needed."
  "$DAEMON" check || true
}

status() {
  if [ -f "$AGENT_PLIST" ]; then echo "installed:  yes (runs at login)"; else echo "installed:  no"; fi
  if is_loaded; then
    local pid
    pid=$(launchctl print "$SERVICE" | awk '/^\tpid =/ {print $3; exit}')
    if [ -n "$pid" ]; then echo "running:    yes, pid $pid"; else echo "running:    loaded but not running"; fi
  else
    echo "running:    no"
  fi
  if command -v ant >/dev/null && ant auth status 2>/dev/null | grep -q "not configured"; then
    echo "anthropic:  not signed in (run \`slackd ant-login\`)"
  elif command -v ant >/dev/null; then
    echo "anthropic:  signed in with ant (\`slackd check\` tests it)"
  else
    echo "anthropic:  ant not installed"
  fi
  if [ -f "$LOG" ]; then
    echo
    tail -n 5 "$LOG"
  fi
}

case "${1:-help}" in
  install)
    write_plist "$AGENT_PLIST"
    rm -f "$SESSION_PLIST"
    load "$AGENT_PLIST"
    echo "slack-daemon installed: running now and at every login (log: $LOG)"
    ;;
  uninstall)
    unload
    rm -f "$AGENT_PLIST" "$SESSION_PLIST"
    echo "slack-daemon uninstalled"
    ;;
  start) start ;;
  stop)
    unload
    echo "slack-daemon stopped"
    ;;
  restart)
    unload
    start
    ;;
  status) status ;;
  logs) exec tail -n 50 -f "$LOG" ;;
  auth) exec "$DAEMON" login ;;
  ant-login) ant_login ;;
  logout | check | channels | once | test-notify) exec "$DAEMON" "$@" ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
