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
  test-alarm                ring a test alarm
  join <meet link>          join now with mic/camera off (if not already in)
  meet-status <meet link>   what the daemon sees in that Meet tab
  google-auth [client.json] connect the Google Calendar API: a guided setup,
                            or straight to sign-in with a client JSON you have
  google-check              test the Google Calendar API connection
EOF
}

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/meeting-daemon"
DOWNLOADS="${MEETING_DAEMON_DOWNLOADS:-$HOME/Downloads}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
dim() { printf '\033[2m%s\033[0m\n' "$*"; }

# Opens a Cloud Console page, shows what to do there, waits for Enter.
console_step() {
  local n=$1 title=$2 url=$3
  shift 3
  echo
  bold "Step $n/5 — $title"
  dim "  $url"
  open "$url"
  printf '  %s\n' "$@"
  read -r -p "  Press Enter when done… " _
}

# Prints the path of a usable Desktop OAuth client JSON, from a path typed
# (or dragged) into the terminal, or a client_secret*.json newly downloaded.
wait_for_client_json() {
  local marker=$1 line file
  while true; do
    if read -r -t 2 line; then
      file=${line//\\ / }
      file=${file//\'/}
      file=${file/#\~/$HOME}
      [ -n "$file" ] || continue
    else
      file=$(find "$DOWNLOADS" -maxdepth 1 -name 'client_secret*.json' -newer "$marker" 2>/dev/null | head -n 1)
      [ -n "$file" ] || continue
      sleep 1 # let the browser finish writing it
    fi
    if jq -e '.installed.client_id and .installed.client_secret' "$file" >/dev/null 2>&1; then
      echo "$file"
      return 0
    elif jq -e '.web' "$file" >/dev/null 2>&1; then
      echo "  $file is a 'Web application' client; create a 'Desktop app' one instead." >&2
    else
      echo "  $file isn't an OAuth client JSON." >&2
    fi
    touch "$marker"
    echo "  Waiting for another file (or type a path)…" >&2
  done
}

google_auth_wizard() {
  local project marker client
  bold "Connect meeting-daemon to the Google Calendar API"
  cat <<EOF

Reading a private calendar needs OAuth, not an API key, and Google only lets
you create the OAuth client by hand in the Cloud Console: about 2 minutes,
once. Each step opens the right page; sign in there with the Google account
whose calendar you want.
EOF
  if [ -f "$CONFIG_DIR/google.json" ]; then
    echo
    read -r -p "Already authorised. Set it up again? [y/N] " again
    [[ $again == [yY]* ]] || return 0
  fi

  console_step 1 "Create a Google Cloud project (or pick one you have)" \
    "https://console.cloud.google.com/projectcreate" \
    "Name it e.g. 'meeting-daemon' and click Create."
  echo
  read -r -p "  Project ID (shown under the name, e.g. meeting-daemon-123456): " project
  local q=""
  [ -n "$project" ] && q="?project=$project"

  console_step 2 "Enable the Google Calendar API" \
    "https://console.cloud.google.com/apis/library/calendar-json.googleapis.com$q" \
    "Click Enable."

  console_step 3 "Set up the OAuth consent screen" \
    "https://console.cloud.google.com/auth/overview$q" \
    "Click 'Get started' (skip if the screen is already configured): app name 'meeting-daemon'," \
    "your email as support and contact address." \
    "Audience: pick 'Internal' if offered (Workspace accounts)." \
    "With 'External' instead, also add yourself as a test user under Audience, and click" \
    "'Publish app' there, or Google expires the sign-in every 7 days."

  marker=$(mktemp)
  console_step 4 "Create the OAuth client" \
    "https://console.cloud.google.com/auth/clients/create$q" \
    "Application type: 'Desktop app', name 'meeting-daemon', click Create," \
    "then 'Download JSON' in the dialog that appears."
  echo "  Waiting for client_secret_*.json in $DOWNLOADS (or type/drag its path here)…"
  client=$(wait_for_client_json "$marker")
  rm -f "$marker"
  mkdir -p "$CONFIG_DIR"
  install -m 600 "$client" "$CONFIG_DIR/client_secret.json"
  rm -f "$client"
  echo "  Got it: moved to $CONFIG_DIR/client_secret.json"

  echo
  bold "Step 5/5 — Sign in and allow read-only calendar access"
  "$DAEMON" google-auth "$CONFIG_DIR/client_secret.json"
}

google_auth() {
  if [ $# -gt 0 ]; then
    "$DAEMON" google-auth "$1"
  else
    google_auth_wizard
  fi
  [ -f "$CONFIG_DIR/google.json" ] || return 0
  "$DAEMON" google-check
  if is_loaded; then
    unload
    start
  fi
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
  if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/meeting-daemon/google.json" ]; then
    echo "google api: authorised"
  else
    echo "google api: off (Calendar.app only)"
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
  google-auth) google_auth "${@:2}" ;;
  upcoming | test-alarm | join | meet-status | google-check) exec "$DAEMON" "$@" ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
