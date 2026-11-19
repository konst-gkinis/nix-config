"""slack-daemond: the program launchd runs (`run`), plus the subcommands the
`slack-daemon` shell wrapper passes through."""

from __future__ import annotations

import json
import logging
import os
import sys
import time
from pathlib import Path

from . import keychain
from .core import watches_all_posts
from .daemon import WARN, Daemon, HaikuUnavailable, Settings, SlackAuthError, State
from .haiku import HaikuTriage
from .login import HINT, LoginFailed, browser_login
from .notify import Notifier
from .slack import Session, SlackClient, SlackError

log = logging.getLogger("slack-daemon")

CONFIG_FILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "slack-daemon" / "config.json"
STATE_FILE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "slack-daemon" / "state.json"
LOGIN_RETRY_SECONDS = 1800


def load_config() -> dict:
    config = {"address_terms": [], "poll_seconds": 60, "eyes_after_seconds": 120}
    if CONFIG_FILE.exists():
        config.update(json.loads(CONFIG_FILE.read_text()))
    return config


def load_state() -> dict:
    try:
        return json.loads(STATE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def save_state(data: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data))
    tmp.replace(STATE_FILE)


class Runner:
    """Owns the long-lived pieces and rebuilds them when the session changes."""

    def __init__(self, config: dict):
        self.config = config
        self.notifier = Notifier()
        self.data = load_state()
        self.data.setdefault("model", {})
        self.daemon: Daemon | None = None
        self.token: str | None = None
        self.last_login = 0.0

    def save(self, state: State) -> None:
        self.data["daemon"] = state.to_dict()
        save_state(self.data)

    def build(self, session: Session) -> Daemon:
        slack = SlackClient(session)
        me = slack.call("users.info", user=session.user_id)["user"]
        name = me.get("real_name") or me.get("profile", {}).get("real_name") or me.get("name", "the user")
        terms = self.config["address_terms"]
        triage = HaikuTriage(
            keychain.anthropic_api_key,
            user_name=name,
            teams=[t for t in terms if t.startswith("@")],
            model_cache=self.data["model"],
        )
        settings = Settings(address_terms=terms, eyes_after_seconds=self.config["eyes_after_seconds"])
        state = State.from_dict(self.data.get("daemon", {}))
        log.info("watching Slack as %s (%s)", name, session.url)
        return Daemon(slack, triage, self.notifier, settings, state, self.save)

    def login(self, reason: str) -> None:
        now = time.time()
        if now - self.last_login < LOGIN_RETRY_SECONDS:
            return
        self.last_login = now
        self.notifier.notify(f"{WARN}slack-daemon: {reason}", f"Opening a Slack sign-in window. {HINT}")
        try:
            session = browser_login()
        except (LoginFailed, SlackError, SlackAuthError) as error:
            log.warning("sign-in failed: %s", error)
            self.notifier.notify(
                f"{WARN}slack-daemon: not signed in",
                f"{error}. Retrying in {LOGIN_RETRY_SECONDS // 60} min, or run `sd auth`.",
            )
            return
        session.store()
        self.notifier.notify("✅ slack-daemon: signed in to Slack", session.url)

    def step(self) -> None:
        session = Session.load()
        if session is None:
            self.login("not signed in to Slack")
            return
        try:
            if self.daemon is None or session.token != self.token:
                self.daemon, self.token = self.build(session), session.token
            self.daemon.tick(time.time())
        except SlackAuthError as error:
            log.warning("Slack session rejected: %s", error)
            self.daemon = None
            self.login("Slack session expired")


def run() -> None:
    config = load_config()
    runner = Runner(config)
    log.info("slack-daemon started; polling every %ss", config["poll_seconds"])
    while True:
        started = time.time()
        try:
            runner.step()
        except (SlackError, OSError) as error:
            log.warning("tick failed: %s", error)
        except Exception:
            log.exception("tick crashed")
        time.sleep(max(1.0, config["poll_seconds"] - (time.time() - started)))


def check() -> int:
    ok = True
    session = Session.load()
    if session is None:
        print("slack:    not signed in (run `sd auth`)")
        ok = False
    else:
        try:
            info = SlackClient(session).call("auth.test")
            print(f"slack:    signed in as {info['user']} on {info['url']}")
        except (SlackError, SlackAuthError, OSError) as error:
            print(f"slack:    session not working: {error} (run `sd auth`)")
            ok = False
    triage = HaikuTriage(keychain.anthropic_api_key, "you", [], model_cache={})
    try:
        print(f"haiku:    API key works; model {triage.check()}")
    except HaikuUnavailable as error:
        print(f"haiku:    {error.detail}")
        ok = False
    return 0 if ok else 1


def channels() -> int:
    """Lists conversations with unread messages and whether they're triaged."""
    session = Session.load()
    if session is None:
        print("not signed in (run `sd auth`)", file=sys.stderr)
        return 1
    slack = SlackClient(session)
    prefs = slack.prefs()
    print(f"global desktop notifications: {prefs.global_desktop}")
    for conversation in slack.counts():
        if not conversation.has_unreads:
            continue
        if watches_all_posts(conversation, prefs):
            verdict = "triaged + 👀"
        elif conversation.mention_count:
            verdict = "👀 only (muted or just mentions, has mentions)"
        else:
            verdict = "ignored (muted or just mentions)"
        print(f"{slack.conversation_label(conversation):40} {verdict}")
    return 0


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("SLACK_DAEMON_LOG", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stdout,
    )
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "run":
        run()
    elif command == "once":
        Runner(load_config()).step()
    elif command == "login":
        print(f"Opening a Slack sign-in window. {HINT}")
        try:
            session = browser_login()
        except (LoginFailed, SlackError, SlackAuthError) as error:
            sys.exit(f"slack-daemond: sign-in failed: {error}")
        session.store()
        print(f"Signed in as {session.user_id} on {session.url}; session stored in the Keychain.")
    elif command == "logout":
        keychain.delete(keychain.SLACK_SERVICE)
        print("Slack session removed from the Keychain.")
    elif command == "check":
        sys.exit(check())
    elif command == "channels":
        sys.exit(channels())
    elif command == "test-notify":
        Notifier().notify("🔴 Test sender in #test-channel", "This is what a slack-daemon notification looks like.")
    else:
        sys.exit("slack-daemond: unknown command; see `slack-daemon help`")


if __name__ == "__main__":
    main()
