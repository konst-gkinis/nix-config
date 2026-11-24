# meeting-daemon: manage the meeting alarm daemon (launchd) and pass the rest
# through to meeting-daemond. DAEMON (the stable symlink launchd runs) and
# ALARM_SOUND are defined above this file by darwin/programs/meeting-daemon.nix.

LABEL=org.nix-config.meeting-daemon
DOMAIN="gui/$(id -u)"
SERVICE="$DOMAIN/$LABEL"
AGENT_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# `start` without `install` loads a plist from here: launchd doesn't read this
# directory at login, so the daemon runs until logout / `stop` only.
SESSION_PLIST="${XDG_STATE_HOME:-$HOME/.local/state}/meeting-daemon/$LABEL.plist"
LOG="$HOME/Library/Logs/meeting-daemon.log"
# Set in the shell to try a sound: MEETING_DAEMON_SOUND=… md test-alarm
export MEETING_DAEMON_SOUND="${MEETING_DAEMON_SOUND:-$ALARM_SOUND}"
BRAVE_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"

usage() {
  cat <<EOF
usage: meeting-daemon <command>   (alias: md <command>)

  install     run at every login from now on, and start now   (md-install)
  uninstall   stop and no longer run at login                 (md-uninstall)
  start       start now (until logout if not installed)       (md start)
  stop        stop now; an installed daemon returns at login  (md-stop)
  restart     stop and start
  status      whether it is installed / running, and setup checks
  logs        follow the log ($LOG)
  silence     stop every ringing alarm

  upcoming [hours]          meetings the daemon would act on (default 12 h)
  unanswered                invites not yet answered, next 14 days (popup every 5 min)
  mute <title>              stop the popups about that invite (whole series)
  unmute <title>            start them again
  test-alarm                ring a test alarm
  join <meet link>          join now with mic/camera off (if not already in)
  meet-status <meet link>   what the daemon sees in that Meet tab
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
  <key>ProcessType</key><string>Interactive</string>
  <key>EnvironmentVariables</key>
  <dict><key>MEETING_DAEMON_SOUND</key><string>$MEETING_DAEMON_SOUND</string></dict>
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
    write_plist "$AGENT_PLIST"
    load "$AGENT_PLIST"
  else
    write_plist "$SESSION_PLIST"
    load "$SESSION_PLIST"
  fi
  echo "meeting-daemon started (log: $LOG)"
}

brave_js_allowed() {
  local prefs found=1
  for prefs in "$BRAVE_DIR"/*/Preferences; do
    [ -f "$prefs" ] || continue
    case "$prefs" in */"System Profile"/* | */"Guest Profile"/*) continue ;; esac
    found=0
    [ "$(jq '.browser.allow_javascript_apple_events // false' "$prefs")" = true ] || return 1
  done
  return $found
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
  if brave_js_allowed; then
    echo "brave:      JavaScript from Apple Events allowed"
  else
    echo "brave:      JavaScript from Apple Events NOT allowed in every profile; auto-join won't work"
    echo "            (quit Brave and run build-switch, or View → Developer → Allow JavaScript from Apple Events)"
  fi
}

case "${1:-help}" in
  install)
    write_plist "$AGENT_PLIST"
    rm -f "$SESSION_PLIST"
    load "$AGENT_PLIST"
    echo "meeting-daemon installed: running now and at every login (log: $LOG)"
    ;;
  uninstall)
    unload
    rm -f "$AGENT_PLIST" "$SESSION_PLIST"
    echo "meeting-daemon uninstalled"
    ;;
  start) start ;;
  stop)
    unload
    echo "meeting-daemon stopped"
    ;;
  restart)
    unload
    start
    ;;
  status) status ;;
  logs) exec tail -n 50 -f "$LOG" ;;
  silence) launchctl kill SIGUSR1 "$SERVICE" ;;
  upcoming | test-alarm | join | meet-status | unanswered | mute | unmute) exec "$DAEMON" "$@" ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
