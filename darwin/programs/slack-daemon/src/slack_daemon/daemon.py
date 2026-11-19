"""One poll of Slack (`Daemon.tick`) and the loop around it. Slack, Haiku,
notifications and persistence are passed in, so the tick is tested with fakes."""

from __future__ import annotations

import logging
import random
from dataclasses import dataclass, field
from typing import Callable, Protocol, Sequence

from .core import (
    ACK_REACTIONS,
    CREDITS_PROBLEM,
    KEY_PROBLEM,
    AddressMatcher,
    Conversation,
    Message,
    NotificationPrefs,
    ack_due,
    group_handles,
    watches_all_posts,
)

log = logging.getLogger("slack-daemon")

RED = "🔴 "
WARN = "⚠️ "
KEEP_SECONDS = 3 * 86400  # how long handled message keys are remembered
PREFS_TTL = 300
USERGROUPS_TTL = 3600
TRIAGE_BATCH = 40

NO_KEY_PROBLEM = "no-key"


class SlackAuthError(Exception):
    """The Slack session is missing, expired or revoked."""


@dataclass(frozen=True)
class Verdict:
    needs_reaction: bool
    summary: str


@dataclass(frozen=True)
class TriageItem:
    key: str
    conversation: str  # "#channel" or "DM with Name"
    sender: str
    text: str
    addressed_to_me: bool
    in_thread: bool


class HaikuUnavailable(Exception):
    def __init__(self, problem: str | None, detail: str):
        super().__init__(detail)
        self.problem = problem  # KEY_PROBLEM, CREDITS_PROBLEM, NO_KEY_PROBLEM or None (transient)
        self.detail = detail


class Slack(Protocol):
    user_id: str

    def counts(self) -> list[Conversation]: ...
    def prefs(self) -> NotificationPrefs: ...
    def usergroup_ids(self, handles: set[str]) -> set[str]: ...
    def unread_messages(self, conversation: Conversation) -> list[Message]: ...
    def react(self, message: Message, name: str) -> None: ...
    def conversation_label(self, conversation: Conversation) -> str: ...
    def user_name(self, user_id: str) -> str: ...
    def permalink(self, message: Message) -> str: ...


class Triage(Protocol):
    def classify(self, items: list[TriageItem]) -> dict[str, Verdict]: ...


class Notifier(Protocol):
    def notify(self, title: str, message: str, open_url: str | None = None) -> None: ...


@dataclass
class State:
    evaluated: dict[str, float] = field(default_factory=dict)  # message key → when sent to Haiku
    reacted: dict[str, float] = field(default_factory=dict)  # message key → when we reacted
    fetched_latest: dict[str, str] = field(default_factory=dict)  # conversation → `latest` last fetched
    pending: list[str] = field(default_factory=list)  # conversations with work left over
    haiku_problem: str | None = None

    @classmethod
    def from_dict(cls, data: dict) -> State:
        known = {k: data[k] for k in cls.__dataclass_fields__ if k in data}
        return cls(**known)

    def to_dict(self) -> dict:
        return {k: getattr(self, k) for k in self.__dataclass_fields__}

    def prune(self, now: float) -> None:
        for seen in (self.evaluated, self.reacted):
            for key in [k for k, at in seen.items() if now - at > KEEP_SECONDS]:
                del seen[key]


@dataclass(frozen=True)
class Settings:
    address_terms: list[str]
    ack_after_seconds: float = 120


HAIKU_PROBLEM_TEXT = {
    KEY_PROBLEM: (
        "Anthropic API key rejected",
        "It has expired or been revoked. Run `slackd set-key` with a new one. Until then messages aren't triaged (reactions still work).",
    ),
    CREDITS_PROBLEM: (
        "Anthropic API out of credits",
        "The credit balance or spend limit is used up. Top up in the Claude Console. Until then messages aren't triaged (reactions still work).",
    ),
    NO_KEY_PROBLEM: (
        "No Anthropic API key",
        "Run `slackd set-key` to store one in the Keychain. Until then messages aren't triaged (reactions still work).",
    ),
}


class Daemon:
    def __init__(
        self,
        slack: Slack,
        triage: Triage,
        notifier: Notifier,
        settings: Settings,
        state: State | None = None,
        save: Callable[[State], None] = lambda state: None,
        choose_reaction: Callable[[Sequence[str]], str] = random.choice,
    ):
        self.slack = slack
        self.triage = triage
        self.notifier = notifier
        self.settings = settings
        self.state = state or State()
        self.save = save
        self.choose_reaction = choose_reaction
        self._prefs: tuple[float, NotificationPrefs] | None = None
        self._matcher: tuple[float, AddressMatcher] | None = None

    def tick(self, now: float) -> None:
        conversations = [c for c in self.slack.counts() if c.has_unreads]
        prefs = self._cached_prefs(now)
        matcher = self._cached_matcher(now)
        pending = set(self.state.pending)
        still_pending: set[str] = set()
        to_triage: list[tuple[Conversation, Message]] = []

        for conversation in conversations:
            watched = watches_all_posts(conversation, prefs)
            # Reactions also cover channels muted or on "just mentions" when they hold a mention.
            ack_scope = watched or conversation.mention_count > 0
            if not ack_scope:
                continue
            if self.state.fetched_latest.get(conversation.id) == conversation.latest and conversation.id not in pending:
                continue
            for message in self.slack.unread_messages(conversation):
                if message.user_id == self.slack.user_id:
                    continue
                if self._ack_waiting(message, matcher, now):
                    still_pending.add(conversation.id)
                if watched and message.key not in self.state.evaluated:
                    to_triage.append((conversation, message))
            self.state.fetched_latest[conversation.id] = conversation.latest

        for start in range(0, len(to_triage), TRIAGE_BATCH):
            batch = to_triage[start : start + TRIAGE_BATCH]
            if not self._triage(batch, matcher, now):
                still_pending.update(c.id for c, _ in to_triage[start:])
                break

        self.state.pending = sorted(still_pending)
        self.state.prune(now)
        self.save(self.state)

    def _ack_waiting(self, message: Message, matcher: AddressMatcher, now: float) -> bool:
        """Reacts to an addressed message unread for long enough, with one of
        ACK_REACTIONS picked at random. True while
        one still has to wait, so its conversation is fetched again."""
        if message.acked_by_me or message.key in self.state.reacted or not matcher.is_addressed(message.text):
            return False
        if not ack_due(message, now, self.settings.ack_after_seconds):
            return True
        reaction = self.choose_reaction(ACK_REACTIONS)
        self.slack.react(message, reaction)
        self.state.reacted[message.key] = now
        log.info("reacted :%s: to %s", reaction, message.key)
        return False

    def _triage(self, batch: list[tuple[Conversation, Message]], matcher: AddressMatcher, now: float) -> bool:
        items = [
            TriageItem(
                key=m.key,
                conversation=self.slack.conversation_label(c),
                sender=self.slack.user_name(m.user_id),
                text=m.text,
                addressed_to_me=matcher.is_addressed(m.text),
                in_thread=m.thread_ts is not None and m.thread_ts != m.ts,
            )
            for c, m in batch
        ]
        try:
            verdicts = self.triage.classify(items)
        except HaikuUnavailable as error:
            log.warning("Haiku unavailable: %s", error.detail)
            if error.problem is not None:
                self._haiku_broken(error.problem)
            return False
        self._haiku_working()
        for (_, message), item in zip(batch, items):
            self.state.evaluated[message.key] = now
            verdict = verdicts.get(message.key)
            if verdict is None:
                log.warning("Haiku returned no verdict for %s", message.key)
                continue
            log.info("%s %s: %s", message.key, "needs you" if verdict.needs_reaction else "skip", verdict.summary)
            if verdict.needs_reaction:
                self.notifier.notify(
                    f"{RED}{item.sender} in {item.conversation}", verdict.summary, self.slack.permalink(message)
                )
        return True

    # Notified once when Haiku stops working for a reason you have to fix
    # (key, credits), and once when it works again; transient errors don't
    # change the state. The flag is persisted, so restarts don't re-notify.
    def _haiku_broken(self, problem: str) -> None:
        if self.state.haiku_problem == problem:
            return
        self.state.haiku_problem = problem
        title, body = HAIKU_PROBLEM_TEXT[problem]
        self.notifier.notify(f"{WARN}slack-daemon: {title}", body)

    def _haiku_working(self) -> None:
        if self.state.haiku_problem is not None:
            self.state.haiku_problem = None
            self.notifier.notify("✅ slack-daemon: Haiku works again", "Message triage has resumed.")

    def _cached_prefs(self, now: float) -> NotificationPrefs:
        if self._prefs is None or now - self._prefs[0] > PREFS_TTL:
            self._prefs = (now, self.slack.prefs())
        return self._prefs[1]

    def _cached_matcher(self, now: float) -> AddressMatcher:
        if self._matcher is None or now - self._matcher[0] > USERGROUPS_TTL:
            ids = self.slack.usergroup_ids(group_handles(self.settings.address_terms))
            self._matcher = (now, AddressMatcher(self.slack.user_id, self.settings.address_terms, ids))
        return self._matcher[1]
