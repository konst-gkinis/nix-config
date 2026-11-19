"""Slack through your own web session (the `xoxc-` token plus the `d` cookie
that app.slack.com uses), the way msga does, so no admin-approved app is
needed. That also opens the client-only endpoints this daemon relies on:
`client.counts` (unread state) and `users.prefs.get` (mute / notification
level per channel). Neither is a public API, so either may change."""

from __future__ import annotations

import json
import logging
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass

from . import keychain
from .core import Conversation, Message, NotificationPrefs, acked_by, parse_counts, parse_prefs
from .daemon import SlackAuthError

log = logging.getLogger("slack-daemon")

AUTH_ERRORS = {"invalid_auth", "not_authed", "token_revoked", "token_expired", "account_inactive"}
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
# Message subtypes that are someone saying something (the rest is joins, topic changes, …).
SPOKEN_SUBTYPES = {None, "bot_message", "thread_broadcast", "file_share", "me_message"}


class SlackError(Exception):
    pass


@dataclass
class Session:
    token: str  # xoxc-…
    cookie: str  # value of the `d` cookie, URL-encoded as the browser stores it
    team_id: str = ""
    user_id: str = ""
    url: str = "https://slack.com/"  # workspace URL, e.g. https://acme.slack.com/

    @classmethod
    def load(cls) -> Session | None:
        raw = keychain.read_b64(keychain.SLACK_SERVICE)
        return cls(**json.loads(raw)) if raw else None

    def store(self) -> None:
        keychain.write_b64(keychain.SLACK_SERVICE, json.dumps(asdict(self)))


def call(session: Session, method: str, **params) -> dict:
    """POSTs a Web API method with the session's token and cookie."""
    data = urllib.parse.urlencode({"token": session.token, **params}).encode()
    request = urllib.request.Request(
        urllib.parse.urljoin(session.url, f"api/{method}"),
        data=data,
        headers={"Cookie": f"d={session.cookie}", "User-Agent": USER_AGENT},
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.load(response)
            break
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 2:
                raise SlackError(f"{method}: HTTP {error.code}") from error
            wait = min(int(error.headers.get("Retry-After", "5")), 30)
            log.info("%s rate limited, waiting %ss", method, wait)
            time.sleep(wait)
    if not payload.get("ok"):
        error = payload.get("error", "unknown_error")
        if error in AUTH_ERRORS:
            raise SlackAuthError(error)
        raise SlackError(f"{method}: {error}")
    return payload


class SlackClient:
    def __init__(self, session: Session):
        self.session = session
        self.user_id = session.user_id
        self._labels: dict[str, str] = {}
        self._names: dict[str, str] = {}

    def call(self, method: str, **params) -> dict:
        return call(self.session, method, **params)

    def counts(self) -> list[Conversation]:
        return parse_counts(self.call("client.counts", thread_counts_by_channel="true"))

    def prefs(self) -> NotificationPrefs:
        return parse_prefs(self.call("users.prefs.get")["prefs"])

    def usergroup_ids(self, handles: set[str]) -> set[str]:
        if not handles:
            return set()
        try:
            groups = self.call("usergroups.list")["usergroups"]
        except SlackError as error:
            log.warning("can't list user groups (%s); matching their handles as text only", error)
            return set()
        found = {g["handle"].lower(): g["id"] for g in groups if g.get("handle", "").lower() in handles}
        for missing in sorted(handles - found.keys()):
            log.warning("no user group @%s; matching it as text only", missing)
        return set(found.values())

    def unread_messages(self, conversation: Conversation) -> list[Message]:
        payload = self.call("conversations.history", channel=conversation.id, oldest=conversation.last_read, limit="100")
        messages = []
        for raw in payload.get("messages", []):
            if raw.get("subtype") not in SPOKEN_SUBTYPES:
                continue
            messages.append(
                Message(
                    channel_id=conversation.id,
                    ts=raw["ts"],
                    user_id=raw.get("user") or raw.get("bot_id") or "",
                    text=_text(raw),
                    acked_by_me=acked_by(raw.get("reactions", []), self.user_id),
                    thread_ts=raw.get("thread_ts"),
                )
            )
        return sorted(messages, key=lambda m: float(m.ts))

    def react(self, message: Message, name: str) -> None:
        try:
            self.call("reactions.add", channel=message.channel_id, timestamp=message.ts, name=name)
        except SlackError as error:
            if "already_reacted" not in str(error):
                raise

    def conversation_label(self, conversation: Conversation) -> str:
        if conversation.id not in self._labels:
            info = self.call("conversations.info", channel=conversation.id)["channel"]
            if info.get("is_im"):
                label = f"DM with {self.user_name(info.get('user', ''))}"
            elif info.get("is_mpim"):
                label = "group DM"
            else:
                label = f"#{info.get('name', conversation.id)}"
            self._labels[conversation.id] = label
        return self._labels[conversation.id]

    def user_name(self, user_id: str) -> str:
        if not user_id.startswith(("U", "W")):
            return "a bot"
        if user_id not in self._names:
            try:
                user = self.call("users.info", user=user_id)["user"]
                profile = user.get("profile", {})
                self._names[user_id] = profile.get("display_name") or profile.get("real_name") or user.get("name", user_id)
            except SlackError:
                self._names[user_id] = user_id
        return self._names[user_id]

    def permalink(self, message: Message) -> str:
        link = f"{self.session.url.rstrip('/')}/archives/{message.channel_id}/p{message.ts.replace('.', '')}"
        if message.thread_ts and message.thread_ts != message.ts:
            link += f"?thread_ts={message.thread_ts}&cid={message.channel_id}"
        return link


def _text(raw: dict) -> str:
    """The message text, plus attachment text (alerts and bots put it there)."""
    parts = [raw.get("text") or ""]
    for attachment in raw.get("attachments", []):
        parts.extend(filter(None, (attachment.get("title"), attachment.get("text") or attachment.get("fallback"))))
    for file in raw.get("files", []):
        if file.get("title"):
            parts.append(f"[file: {file['title']}]")
    return "\n".join(p for p in parts if p).strip()
