"""Signs in to Slack in a throwaway browser profile and keeps the session.

Opens Brave (or Chrome / Chromium / Edge) with a fresh --user-data-dir and a
DevTools port, at app.slack.com. Once you've signed in and the web client has
loaded, it reads the `d` cookie and the workspace's `xoxc-` token (from
localStorage) over the DevTools protocol, closes the window, and deletes the
profile. Your normal browser profile is never touched."""

from __future__ import annotations

import json
import logging
import os
import re
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request

import websocket

from .slack import Session, call

log = logging.getLogger("slack-daemon")

BROWSERS = [
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]
START_URL = "https://app.slack.com/client"


class LoginFailed(Exception):
    pass


def find_browser() -> str:
    override = os.environ.get("SLACK_DAEMON_BROWSER")
    for path in [override] if override else BROWSERS:
        if path and os.access(path, os.X_OK):
            return path
    raise LoginFailed("no Chromium-based browser found (set SLACK_DAEMON_BROWSER to its binary)")


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _cdp(ws: websocket.WebSocket, method: str, params: dict | None = None) -> dict:
    request_id = int(time.time() * 1000) % 1_000_000_000
    ws.send(json.dumps({"id": request_id, "method": method, "params": params or {}}))
    while True:
        reply = json.loads(ws.recv())
        if reply.get("id") == request_id:
            if "error" in reply:
                raise LoginFailed(f"{method}: {reply['error']}")
            return reply["result"]


def _session_from_page(target: dict, team_hint: str | None) -> Session | None:
    """Reads the token and cookie from a loaded app.slack.com/client tab."""
    ws = websocket.create_connection(target["webSocketDebuggerUrl"], timeout=10, suppress_origin=True)
    try:
        cookies = _cdp(ws, "Network.getCookies", {"urls": ["https://app.slack.com/"]})["cookies"]
        cookie = next((c["value"] for c in cookies if c["name"] == "d"), None)
        result = _cdp(
            ws,
            "Runtime.evaluate",
            {"expression": "localStorage.getItem('localConfig_v2')", "returnByValue": True},
        )["result"]
    finally:
        ws.close()
    config = json.loads(result.get("value") or "null") or {}
    teams = config.get("teams") or {}
    if not cookie or not teams:
        return None
    match = re.search(r"/client/(T\w+)", target.get("url", ""))
    team_id = team_hint or (match.group(1) if match else None) or config.get("lastActiveTeamId") or next(iter(teams))
    team = teams.get(team_id)
    if not team or not str(team.get("token", "")).startswith("xoxc-"):
        return None
    return Session(token=team["token"], cookie=cookie, team_id=team_id, url=team.get("url") or "https://slack.com/")


def browser_login(timeout: float = 600, team_hint: str | None = None) -> Session:
    browser = find_browser()
    profile = tempfile.mkdtemp(prefix="slack-daemon-login-")
    port = _free_port()
    log.info("opening Slack sign-in in %s", os.path.basename(browser))
    process = subprocess.Popen(
        [
            browser,
            f"--user-data-dir={profile}",
            f"--remote-debugging-port={port}",
            "--no-first-run",
            "--no-default-browser-check",
            "--new-window",
            START_URL,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if process.poll() is not None:
                raise LoginFailed("the sign-in window was closed before signing in")
            time.sleep(2)
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=5) as response:
                    targets = json.load(response)
            except OSError:
                continue
            for target in targets:
                if target.get("type") != "page" or not target.get("url", "").startswith(START_URL):
                    continue
                try:
                    session = _session_from_page(target, team_hint)
                except (OSError, websocket.WebSocketException, LoginFailed, ValueError) as error:
                    log.debug("not signed in yet: %s", error)
                    continue
                if session:
                    return verify(session)
        raise LoginFailed(f"not signed in within {int(timeout // 60)} minutes")
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
        shutil.rmtree(profile, ignore_errors=True)


def verify(session: Session) -> Session:
    """Fills in the user and workspace from auth.test (and proves the session works)."""
    info = call(session, "auth.test")
    session.user_id = info["user_id"]
    session.team_id = info["team_id"]
    session.url = info.get("url") or session.url
    return session
