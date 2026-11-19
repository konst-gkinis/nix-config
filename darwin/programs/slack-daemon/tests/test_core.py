import json

import pytest
from builders import MY_GROUP_ID, MY_USER_ID, build_conversation, build_prefs

from slack_daemon.core import (
    CREDITS_PROBLEM,
    KEY_PROBLEM,
    AddressMatcher,
    acked_by,
    anthropic_problem,
    latest_haiku,
    parse_counts,
    parse_prefs,
    watches_all_posts,
)


@pytest.mark.parametrize(
    "conversation_overrides, prefs_overrides, expected",
    [
        pytest.param({"kind": "im"}, {"global_desktop": "mentions"}, True, id="dm is watched whatever the global level"),
        pytest.param({"id": "C_MUTED", "kind": "im"}, {"muted": frozenset({"C_MUTED"})}, False, id="muted dm"),
        pytest.param({"id": "C_ALL"}, {"global_desktop": "mentions", "channel_desktop": {"C_ALL": "everything"}}, True, id="channel set to all new messages"),
        pytest.param({"id": "C_MENTIONS"}, {"channel_desktop": {"C_MENTIONS": "mentions"}}, False, id="channel set to just mentions"),
        pytest.param({"id": "C_NOTHING"}, {"channel_desktop": {"C_NOTHING": "nothing"}}, False, id="channel set to nothing"),
        pytest.param({"id": "C_DEFAULT"}, {"global_desktop": "everything", "channel_desktop": {"C_DEFAULT": "default"}}, True, id="default follows global all new messages"),
        pytest.param({}, {"global_desktop": "mentions"}, False, id="no setting follows global just mentions"),
        pytest.param({"id": "C_MUTED"}, {"channel_desktop": {"C_MUTED": "everything"}, "muted": frozenset({"C_MUTED"})}, False, id="muted channel on all new messages"),
    ],
)
def test_watches_all_posts(conversation_overrides, prefs_overrides, expected):
    conversation = build_conversation(**conversation_overrides)
    prefs = build_prefs(**prefs_overrides)

    watched = watches_all_posts(conversation, prefs)

    assert watched is expected


def test_parse_prefs_reads_muting_from_both_the_list_and_the_per_channel_flag():
    raw = {
        "muted_channels": "C_MUTED_BY_LIST",
        "all_notifications_prefs": json.dumps({"channels": {"C_MUTED_BY_FLAG": {"muted": True}}}),
    }

    prefs = parse_prefs(raw)

    assert prefs.muted == {"C_MUTED_BY_LIST", "C_MUTED_BY_FLAG"}


def test_parse_prefs_reads_desktop_levels():
    raw = {
        "all_notifications_prefs": json.dumps(
            {"channels": {"C_CHANNEL": {"desktop": "everything"}}, "global": {"global_desktop": "nothing"}}
        )
    }

    prefs = parse_prefs(raw)

    assert (prefs.global_desktop, prefs.channel_desktop) == ("nothing", {"C_CHANNEL": "everything"})


def test_parse_counts_keeps_the_conversation_kind():
    payload = {"channels": [{"id": "C_CHANNEL"}], "ims": [{"id": "D_IM"}], "mpims": [{"id": "G_MPIM"}]}

    conversations = parse_counts(payload)

    assert [(c.id, c.kind) for c in conversations] == [("C_CHANNEL", "channel"), ("D_IM", "im"), ("G_MPIM", "mpim")]


@pytest.mark.parametrize(
    "text, expected",
    [
        pytest.param(f"hey <@{MY_USER_ID}> can you look", True, id="user mention"),
        pytest.param(f"hey <@{MY_USER_ID}|someone>", True, id="labelled user mention"),
        pytest.param(f"<!subteam^{MY_GROUP_ID}|@my-group> please review", True, id="my user group"),
        pytest.param("<!subteam^S_OTHER_GROUP|@other-group> please review", False, id="other user group"),
        pytest.param("Is FULL NAME around?", True, id="phrase in any case"),
        pytest.param("ping @my-group about this", True, id="group handle as plain text"),
        pytest.param("ping @my-group-oncall about this", False, id="longer handle is not a match"),
        pytest.param("<@U_SOMEONE_ELSE> MESSAGE_TEXT", False, id="someone else"),
    ],
)
def test_address_matcher(text, expected):
    matcher = AddressMatcher(MY_USER_ID, ["full name", "@my-group"], {MY_GROUP_ID})

    addressed = matcher.is_addressed(text)

    assert addressed is expected


def test_latest_haiku_picks_the_newest_haiku():
    models = [("claude-haiku-OLD", 100.0), ("claude-haiku-NEW", 200.0), ("claude-opus-NEWEST", 300.0)]

    chosen = latest_haiku(models)

    assert chosen == "claude-haiku-NEW"


def test_latest_haiku_is_none_without_haiku_models():
    chosen = latest_haiku([("claude-opus-ONLY", 100.0)])

    assert chosen is None


@pytest.mark.parametrize(
    "status, error_type, message, error_code, expected",
    [
        pytest.param(401, "authentication_error", "invalid x-api-key", None, KEY_PROBLEM, id="expired key"),
        pytest.param(403, "permission_error", "not allowed", None, KEY_PROBLEM, id="key without permission"),
        pytest.param(402, "billing_error", "payment problem", None, CREDITS_PROBLEM, id="billing error"),
        pytest.param(400, "invalid_request_error", "Your credit balance is too low", None, CREDITS_PROBLEM, id="credit balance too low"),
        pytest.param(429, "rate_limit_error", "spend limit", "enforced_spend_limit_reached", CREDITS_PROBLEM, id="spend cap"),
        pytest.param(429, "rate_limit_error", "slow down", None, None, id="ordinary rate limit"),
        pytest.param(529, "overloaded_error", "overloaded", None, None, id="overloaded"),
    ],
)
def test_anthropic_problem(status, error_type, message, error_code, expected):
    problem = anthropic_problem(status, error_type, message, error_code)

    assert problem == expected



@pytest.mark.parametrize(
    "reactions, expected",
    [
        pytest.param([{"name": "eye", "users": [MY_USER_ID]}], True, id="one of the acknowledgements"),
        pytest.param([{"name": "+1::skin-tone-3", "users": [MY_USER_ID]}], True, id="skin tone variant"),
        pytest.param([{"name": "eyes", "users": ["U_SOMEONE_ELSE"]}], False, id="added by someone else"),
        pytest.param([{"name": "heart", "users": [MY_USER_ID]}], False, id="not an acknowledgement"),
    ],
)
def test_acked_by(reactions, expected):
    acked = acked_by(reactions, MY_USER_ID)

    assert acked is expected
