import pytest

from slack_daemon import ant
from slack_daemon.daemon import NO_LOGIN_PROBLEM, HaikuUnavailable
from slack_daemon.haiku import HaikuTriage


def fake_ant(tmp_path, monkeypatch, script: str) -> None:
    """Points the lookup at a stand-in `ant` that runs `script`."""
    path = tmp_path / "ant"
    path.write_text(f"#!/bin/sh\n{script}\n")
    path.chmod(0o755)
    monkeypatch.setattr(ant, "ANT", str(path))


def not_signed_in() -> str:
    raise ant.NotSignedIn("NOT_SIGNED_IN_DETAIL")


def test_access_token_is_what_ant_prints(tmp_path, monkeypatch):
    fake_ant(tmp_path, monkeypatch, 'echo "ACCESS_TOKEN"')

    token = ant.access_token()

    assert token == "ACCESS_TOKEN"


def test_access_token_raises_not_signed_in_when_ant_fails(tmp_path, monkeypatch):
    fake_ant(tmp_path, monkeypatch, 'echo "ANT_ERROR_LINE" >&2; exit 1')

    with pytest.raises(ant.NotSignedIn, match="ANT_ERROR_LINE"):
        ant.access_token()


def test_access_token_raises_not_signed_in_when_ant_is_missing(tmp_path, monkeypatch):
    monkeypatch.setattr(ant, "ANT", str(tmp_path / "MISSING_ANT"))

    with pytest.raises(ant.NotSignedIn, match="not found"):
        ant.access_token()


def test_triage_reports_no_login_when_ant_is_not_signed_in():
    triage = HaikuTriage(not_signed_in, "USER_NAME", [], model_cache={})

    with pytest.raises(HaikuUnavailable) as raised:
        triage.check()

    assert raised.value.problem == NO_LOGIN_PROBLEM
