"""Pure decision logic: which conversations to watch, which messages are
addressed to you, which Haiku model is newest, and what an Anthropic error
means. No I/O here, so it is all unit-tested."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

DIRECT_KINDS = ("im", "mpim")


@dataclass(frozen=True)
class Conversation:
    id: str
    kind: str  # "channel", "im" or "mpim"
    last_read: str
    latest: str
    mention_count: int = 0

    @property
    def has_unreads(self) -> bool:
        return ts_value(self.latest) > ts_value(self.last_read)


@dataclass(frozen=True)
class NotificationPrefs:
    global_desktop: str  # "everything", "mentions" or "nothing"
    channel_desktop: dict[str, str] = field(default_factory=dict)
    muted: frozenset[str] = frozenset()


@dataclass(frozen=True)
class Message:
    channel_id: str
    ts: str
    user_id: str
    text: str
    eyes_by_me: bool = False
    thread_ts: str | None = None

    @property
    def key(self) -> str:
        return f"{self.channel_id}:{self.ts}"


def ts_value(ts: str | None) -> float:
    try:
        return float(ts or 0)
    except ValueError:
        return 0.0


def parse_counts(payload: dict) -> list[Conversation]:
    """client.counts → one Conversation per channel, DM and group DM."""
    conversations = []
    for section, kind in (("channels", "channel"), ("ims", "im"), ("mpims", "mpim")):
        for entry in payload.get(section) or []:
            conversations.append(
                Conversation(
                    id=entry["id"],
                    kind=kind,
                    last_read=entry.get("last_read") or "0",
                    latest=entry.get("latest") or "0",
                    mention_count=int(entry.get("mention_count") or 0),
                )
            )
    return conversations


def parse_prefs(prefs: dict) -> NotificationPrefs:
    """users.prefs.get's `prefs` → desktop notification level per channel.

    `all_notifications_prefs` is a JSON string. Muting has lived both in the
    comma-separated `muted_channels` pref and in a per-channel `muted` flag,
    so both are read."""
    raw = prefs.get("all_notifications_prefs") or "{}"
    notifications = json.loads(raw) if isinstance(raw, str) else raw
    muted = {c for c in (prefs.get("muted_channels") or "").split(",") if c}
    channel_desktop = {}
    for channel_id, settings in (notifications.get("channels") or {}).items():
        if settings.get("muted"):
            muted.add(channel_id)
        desktop = settings.get("desktop")
        if desktop:
            channel_desktop[channel_id] = desktop
    global_desktop = (notifications.get("global") or {}).get("global_desktop") or "mentions"
    return NotificationPrefs(global_desktop, channel_desktop, frozenset(muted))


def watches_all_posts(conversation: Conversation, prefs: NotificationPrefs) -> bool:
    """True for unmuted DMs / group DMs and unmuted channels notifying on
    "All new messages" (their own setting, or the global one by default)."""
    if conversation.id in prefs.muted:
        return False
    if conversation.kind in DIRECT_KINDS:
        return True
    level = prefs.channel_desktop.get(conversation.id, "default")
    if level == "default":
        level = prefs.global_desktop
    return level == "everything"


class AddressMatcher:
    """Decides whether a message is addressed to you: a mention of your user
    ID or of one of your user groups, or one of the configured phrases as a
    whole word (case-insensitive). Mentions arrive encoded (`<@U123>`,
    `<!subteam^S123|@handle>`), so plain text matching alone would miss them."""

    def __init__(self, user_id: str, phrases: list[str], usergroup_ids: set[str]):
        self.user_id = user_id
        self.usergroup_ids = usergroup_ids
        self.patterns = [
            re.compile(r"(?<![\w-])" + re.escape(p.lower()) + r"(?![\w-])") for p in phrases if p.strip()
        ]

    def is_addressed(self, text: str) -> bool:
        if re.search(rf"<@{re.escape(self.user_id)}(\|[^>]*)?>", text):
            return True
        for group_id in re.findall(r"<!subteam\^(\w+)", text):
            if group_id in self.usergroup_ids:
                return True
        lowered = text.lower()
        return any(p.search(lowered) for p in self.patterns)


def group_handles(phrases: list[str]) -> set[str]:
    """The '@handle' phrases, without the '@': candidates for user groups."""
    return {p.strip()[1:].lower() for p in phrases if p.strip().startswith("@")}


def eyes_due(message: Message, now: float, after_seconds: float) -> bool:
    return now - ts_value(message.ts) >= after_seconds


def latest_haiku(models: list[tuple[str, float]]) -> str | None:
    """The newest `claude-haiku-*` model from (id, created_at epoch) pairs."""
    haikus = [(created, model_id) for model_id, created in models if model_id.startswith("claude-haiku-")]
    return max(haikus)[1] if haikus else None


# What a failed Anthropic call means for you. Transient failures (overload,
# ordinary rate limits, network) return None: the next tick just retries.
KEY_PROBLEM = "key"
CREDITS_PROBLEM = "credits"


def anthropic_problem(status: int | None, error_type: str | None, message: str, error_code: str | None) -> str | None:
    if status in (401, 403) or error_type in ("authentication_error", "permission_error"):
        return KEY_PROBLEM
    if status == 402 or error_type == "billing_error":
        return CREDITS_PROBLEM
    if status == 400 and "credit balance" in message.lower():
        return CREDITS_PROBLEM
    if status == 429 and error_code == "enforced_spend_limit_reached":
        return CREDITS_PROBLEM
    return None
