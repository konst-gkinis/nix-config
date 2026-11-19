"""Test-only builders and fakes. Defaults are valid and boring: an unmuted
channel on "All new messages" with one unread message from someone else."""

from __future__ import annotations

import itertools
from dataclasses import dataclass, field, replace

from slack_daemon.core import Conversation, Message, NotificationPrefs
from slack_daemon.daemon import Daemon, HaikuUnavailable, Settings, TriageItem, Verdict

NOW = 1_800_000_000.0
MY_USER_ID = "U_MY_USER_ID"
OTHER_USER_ID = "U_OTHER_USER_ID"
MY_GROUP_ID = "S_MY_GROUP_ID"
_ids = itertools.count(1)


def ts_ago(seconds: float) -> str:
    return f"{NOW - seconds:.6f}"


def build_conversation(**overrides) -> Conversation:
    defaults = dict(
        id=f"C_CHANNEL_{next(_ids)}",
        kind="channel",
        last_read=ts_ago(3600),
        latest=ts_ago(10),
        mention_count=0,
    )
    return Conversation(**(defaults | overrides))


def build_prefs(**overrides) -> NotificationPrefs:
    defaults = dict(global_desktop="everything", channel_desktop={}, muted=frozenset())
    return NotificationPrefs(**(defaults | overrides))


def build_message(conversation: Conversation, **overrides) -> Message:
    defaults = dict(
        channel_id=conversation.id,
        ts=conversation.latest,
        user_id=OTHER_USER_ID,
        text="MESSAGE_TEXT",
    )
    return Message(**(defaults | overrides))


def build_settings(**overrides) -> Settings:
    defaults = dict(address_terms=["full name", "@my-group"], ack_after_seconds=120)
    return Settings(**(defaults | overrides))


@dataclass
class FakeSlack:
    conversations: list[Conversation] = field(default_factory=list)
    messages: list[Message] = field(default_factory=list)
    notification_prefs: NotificationPrefs = field(default_factory=build_prefs)
    reactions: list[tuple[str, str]] = field(default_factory=list)
    history_calls: int = 0
    user_id: str = MY_USER_ID

    def counts(self):
        return list(self.conversations)

    def prefs(self):
        return self.notification_prefs

    def usergroup_ids(self, handles):
        return {MY_GROUP_ID} if "my-group" in handles else set()

    def unread_messages(self, conversation):
        self.history_calls += 1
        return [
            m for m in self.messages if m.channel_id == conversation.id and float(m.ts) > float(conversation.last_read)
        ]

    def react(self, message, name):
        self.reactions.append((message.key, name))

    def conversation_label(self, conversation):
        return f"#{conversation.id}"

    def user_name(self, user_id):
        return f"NAME_OF_{user_id}"

    def permalink(self, message):
        return f"https://PERMALINK/{message.key}"

    def mark_read(self, conversation: Conversation) -> None:
        index = self.conversations.index(conversation)
        self.conversations[index] = replace(conversation, last_read=conversation.latest)


class FakeTriage:
    """Answers every message with one verdict, or raises the given error."""

    def __init__(self, needs_reaction: bool = False, summary: str = "VERDICT_SUMMARY"):
        self.verdict = Verdict(needs_reaction, summary)
        self.error: HaikuUnavailable | None = None
        self.seen: list[TriageItem] = []

    def classify(self, items):
        if self.error:
            raise self.error
        self.seen.extend(items)
        return {item.key: self.verdict for item in items}


@dataclass
class RecordingNotifier:
    sent: list[tuple[str, str, str | None]] = field(default_factory=list)

    def notify(self, title, message, open_url=None):
        self.sent.append((title, message, open_url))


def build_daemon(
    slack: FakeSlack,
    triage: FakeTriage | None = None,
    notifier: RecordingNotifier | None = None,
    choose_reaction=lambda options: options[0],
):
    return Daemon(
        slack, triage or FakeTriage(), notifier or RecordingNotifier(), build_settings(), choose_reaction=choose_reaction
    )


def build_world(conversation: Conversation | None = None, **message_overrides) -> FakeSlack:
    """A Slack with one conversation holding one unread message."""
    conversation = conversation or build_conversation()
    return FakeSlack(conversations=[conversation], messages=[build_message(conversation, **message_overrides)])
