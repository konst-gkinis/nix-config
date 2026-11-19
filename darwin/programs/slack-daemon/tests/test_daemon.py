from builders import (
    MY_USER_ID,
    NOW,
    FakeTriage,
    RecordingNotifier,
    build_conversation,
    build_daemon,
    build_prefs,
    build_world,
    ts_ago,
)

from slack_daemon.core import CREDITS_PROBLEM, KEY_PROBLEM
from slack_daemon.daemon import HaikuUnavailable


def test_notifies_with_a_red_circle_when_haiku_says_you_need_to_react():
    slack = build_world()
    notifier = RecordingNotifier()
    daemon = build_daemon(slack, FakeTriage(needs_reaction=True, summary="ASKED_TO_REVIEW"), notifier)

    daemon.tick(NOW)

    [(title, message, _)] = notifier.sent
    assert title.startswith("🔴 ")
    assert message == "ASKED_TO_REVIEW"


def test_does_not_notify_when_haiku_says_no_reaction_is_needed():
    slack = build_world()
    notifier = RecordingNotifier()
    daemon = build_daemon(slack, FakeTriage(needs_reaction=False), notifier)

    daemon.tick(NOW)

    assert notifier.sent == []


def test_sends_each_message_to_haiku_only_once_even_when_fetched_again():
    slack = build_world(build_conversation(id="C_REFETCHED_FOR_PENDING_EYES"), text="full name", ts=ts_ago(10))
    triage = FakeTriage()
    daemon = build_daemon(slack, triage)

    daemon.tick(NOW)
    daemon.tick(NOW + 60)

    assert len(triage.seen) == 1


def test_does_not_triage_a_channel_on_just_mentions():
    conversation = build_conversation(id="C_JUST_MENTIONS")
    slack = build_world(conversation)
    slack.notification_prefs = build_prefs(channel_desktop={"C_JUST_MENTIONS": "mentions"})
    triage = FakeTriage()
    daemon = build_daemon(slack, triage)

    daemon.tick(NOW)

    assert triage.seen == []


def test_ignores_your_own_messages():
    slack = build_world(user_id=MY_USER_ID, text="full name")
    triage = FakeTriage()
    daemon = build_daemon(slack, triage)

    daemon.tick(NOW)

    assert (triage.seen, slack.reactions) == ([], [])


def test_adds_eyes_to_an_addressed_message_unread_for_two_minutes():
    slack = build_world(ts=ts_ago(120), text="full name, can you check?")
    daemon = build_daemon(slack)

    daemon.tick(NOW)

    assert [name for _, name in slack.reactions] == ["eyes"]


def test_does_not_add_eyes_before_two_minutes():
    slack = build_world(ts=ts_ago(119), text="full name, can you check?")
    daemon = build_daemon(slack)

    daemon.tick(NOW)

    assert slack.reactions == []


def test_adds_eyes_on_a_later_tick_once_two_minutes_have_passed():
    slack = build_world(ts=ts_ago(60), text="full name, can you check?")
    daemon = build_daemon(slack)

    daemon.tick(NOW)
    daemon.tick(NOW + 60)

    assert [name for _, name in slack.reactions] == ["eyes"]


def test_does_not_add_eyes_once_the_message_was_read():
    conversation = build_conversation()
    slack = build_world(conversation, ts=ts_ago(60), text="full name, can you check?")
    daemon = build_daemon(slack)

    daemon.tick(NOW)
    slack.mark_read(conversation)
    daemon.tick(NOW + 60)

    assert slack.reactions == []


def test_adds_eyes_in_a_muted_channel_with_a_mention():
    conversation = build_conversation(id="C_MUTED", mention_count=1)
    slack = build_world(conversation, ts=ts_ago(120), text=f"<@{MY_USER_ID}> help")
    slack.notification_prefs = build_prefs(muted=frozenset({"C_MUTED"}))
    daemon = build_daemon(slack)

    daemon.tick(NOW)

    assert [name for _, name in slack.reactions] == ["eyes"]


def test_does_not_fetch_a_conversation_again_when_nothing_changed():
    slack = build_world()
    daemon = build_daemon(slack)

    daemon.tick(NOW)
    daemon.tick(NOW + 60)

    assert slack.history_calls == 1


def test_notifies_once_when_haiku_is_out_of_credits():
    slack = build_world()
    triage = FakeTriage()
    triage.error = HaikuUnavailable(CREDITS_PROBLEM, "DETAIL")
    notifier = RecordingNotifier()
    daemon = build_daemon(slack, triage, notifier)

    daemon.tick(NOW)
    daemon.tick(NOW + 60)

    [(title, _, _)] = notifier.sent
    assert "out of credits" in title


def test_notifies_when_the_api_key_is_rejected():
    slack = build_world()
    triage = FakeTriage()
    triage.error = HaikuUnavailable(KEY_PROBLEM, "DETAIL")
    notifier = RecordingNotifier()
    daemon = build_daemon(slack, triage, notifier)

    daemon.tick(NOW)

    [(title, _, _)] = notifier.sent
    assert "API key rejected" in title


def test_does_not_notify_about_transient_haiku_errors():
    slack = build_world()
    triage = FakeTriage()
    triage.error = HaikuUnavailable(None, "overloaded")
    notifier = RecordingNotifier()
    daemon = build_daemon(slack, triage, notifier)

    daemon.tick(NOW)

    assert notifier.sent == []


def test_triages_held_back_messages_once_haiku_works_again():
    slack = build_world(build_conversation(id="C_CHANNEL"))
    triage = FakeTriage(needs_reaction=True)
    triage.error = HaikuUnavailable(CREDITS_PROBLEM, "DETAIL")
    notifier = RecordingNotifier()
    daemon = build_daemon(slack, triage, notifier)

    daemon.tick(NOW)
    triage.error = None
    daemon.tick(NOW + 60)

    assert [title.split(":")[0] for title, _, _ in notifier.sent] == [
        "⚠️ slack-daemon",
        "✅ slack-daemon",
        "🔴 NAME_OF_U_OTHER_USER_ID in #C_CHANNEL",
    ]
