"""Message triage with the newest Claude Haiku (looked up daily through the
Models API) and the API key from the macOS Keychain."""

from __future__ import annotations

import json
import logging
import time
from typing import Callable

import anthropic
from pydantic import BaseModel

from .core import anthropic_problem, latest_haiku
from .daemon import NO_KEY_PROBLEM, HaikuUnavailable, TriageItem, Verdict

log = logging.getLogger("slack-daemon")

FALLBACK_MODEL = "claude-haiku-5-5"
MODEL_TTL = 86400

SYSTEM = """You triage unread Slack messages for {name}, a software engineer.
For each message decide whether {name} personally needs to react: reply, answer a
question, make a decision, review or approve something, unblock someone, take an
action, or urgently know about an incident affecting their work.

Does NOT need a reaction: general chatter, FYIs and announcements that ask nothing
of them, automated noise, messages clearly aimed at someone else, questions
someone else already answered, thanks/acknowledgements, social messages.

`addressed_to_me` is true when the message mentions {name}, their user ID, or one
of their teams ({teams}); weigh it heavily but still judge the content. Direct
messages are usually aimed at them.

For each message return its id, needs_reaction, and a summary: one short line
(max ~100 characters) saying what is asked of {name}, written to be shown as a
desktop notification. Return a verdict for every message."""


class _Verdict(BaseModel):
    id: str
    needs_reaction: bool
    summary: str


class _Verdicts(BaseModel):
    verdicts: list[_Verdict]


class HaikuTriage:
    def __init__(
        self,
        api_key: Callable[[], str | None],
        user_name: str,
        teams: list[str],
        model_cache: dict,
        clock: Callable[[], float] = time.time,
    ):
        self.api_key = api_key
        self.system = SYSTEM.format(name=user_name, teams=", ".join(teams) or "none")
        self.model_cache = model_cache  # persisted {"id": …, "checked_at": …}
        self.clock = clock

    def _client(self) -> anthropic.Anthropic:
        key = self.api_key()
        if not key:
            raise HaikuUnavailable(NO_KEY_PROBLEM, "no Anthropic API key in the Keychain")
        return anthropic.Anthropic(api_key=key, max_retries=2, timeout=120)

    def model(self, client: anthropic.Anthropic, refresh: bool = False) -> str:
        cached = self.model_cache.get("id")
        if cached and not refresh and self.clock() - self.model_cache.get("checked_at", 0) < MODEL_TTL:
            return cached
        try:
            models = [(m.id, m.created_at.timestamp()) for m in client.models.list()]
        except anthropic.APIStatusError as error:
            raise _unavailable(error) from error
        except anthropic.APIConnectionError:
            return cached or FALLBACK_MODEL
        chosen = latest_haiku(models) or FALLBACK_MODEL
        if chosen != cached:
            log.info("using %s", chosen)
        self.model_cache.update(id=chosen, checked_at=self.clock())
        return chosen

    def classify(self, items: list[TriageItem]) -> dict[str, Verdict]:
        client = self._client()
        payload = json.dumps(
            [
                {
                    "id": i.key,
                    "conversation": i.conversation,
                    "sender": i.sender,
                    "addressed_to_me": i.addressed_to_me,
                    "thread_reply": i.in_thread,
                    "text": i.text,
                }
                for i in items
            ],
            ensure_ascii=False,
        )
        model = self.model(client)
        try:
            response = self._parse(client, model, payload)
        except anthropic.NotFoundError:
            # The cached model was retired; look up the newest again.
            response = self._parse(client, self.model(client, refresh=True), payload)
        if response.stop_reason == "refusal" or response.parsed_output is None:
            log.warning("Haiku gave no verdicts (stop_reason %s)", response.stop_reason)
            return {}
        return {v.id: Verdict(v.needs_reaction, v.summary) for v in response.parsed_output.verdicts}

    def _parse(self, client: anthropic.Anthropic, model: str, payload: str):
        try:
            return client.messages.parse(
                model=model,
                max_tokens=8000,
                system=self.system,
                messages=[{"role": "user", "content": payload}],
                output_format=_Verdicts,
                output_config={"effort": "low"},
            )
        except anthropic.NotFoundError:
            raise
        except anthropic.APIStatusError as error:
            raise _unavailable(error) from error
        except anthropic.APIConnectionError as error:
            raise HaikuUnavailable(None, f"network: {error}") from error

    def check(self) -> str:
        """For `sd check`: proves the key works and names the model in use."""
        client = self._client()
        return self.model(client, refresh=True)


def _unavailable(error: anthropic.APIStatusError) -> HaikuUnavailable:
    body = error.body if isinstance(error.body, dict) else {}
    detail = body.get("error") if isinstance(body.get("error"), dict) else {}
    error_code = (detail.get("details") or {}).get("error_code") if isinstance(detail.get("details"), dict) else None
    problem = anthropic_problem(error.status_code, detail.get("type"), str(detail.get("message") or error), error_code)
    return HaikuUnavailable(problem, f"{error.status_code} {detail.get('type')}: {detail.get('message') or error}")
