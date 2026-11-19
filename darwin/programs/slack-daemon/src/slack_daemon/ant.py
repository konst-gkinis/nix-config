"""Anthropic credentials from the `ant` CLI (Homebrew, anthropics/tap/ant).

`ant auth login` signs in through the browser (OAuth) and keeps the tokens in
~/.config/anthropic; `print-credentials` refreshes the access token when it is
expired or near expiry, so asking on every call is all the upkeep needed."""

from __future__ import annotations

import os
import shutil
import subprocess

# The daemon's wrapper puts the Homebrew bin directories on PATH; this
# overrides the lookup.
ANT = os.environ.get("SLACK_DAEMON_ANT", "ant")


class NotSignedIn(Exception):
    """ant is missing, not logged in, or couldn't refresh the token."""


def access_token() -> str:
    ant = shutil.which(ANT)
    if ant is None:
        raise NotSignedIn(f"`{ANT}` not found on PATH (brew install anthropics/tap/ant)")
    try:
        result = subprocess.run(
            [ant, "auth", "print-credentials", "--access-token"],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired as error:
        raise NotSignedIn("`ant auth print-credentials` timed out") from error
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        detail = result.stderr.strip().splitlines()
        raise NotSignedIn(f"ant has no Anthropic login ({detail[-1] if detail else f'exit {result.returncode}'})")
    return token
