"""macOS notifications through terminal-notifier (clicking one opens the
message), with osascript as a fallback."""

from __future__ import annotations

import logging
import os
import shutil
import subprocess

log = logging.getLogger("slack-daemon")


class Notifier:
    def __init__(self):
        self.binary = os.environ.get("SLACK_DAEMON_NOTIFIER") or shutil.which("terminal-notifier")

    def notify(self, title: str, message: str, open_url: str | None = None) -> None:
        log.info("notify: %s | %s", title, message)
        if self.binary:
            command = [self.binary, "-title", title, "-message", message, "-sound", "default", "-group", title]
            if open_url:
                command += ["-open", open_url]
        else:
            script = "on run argv\ndisplay notification (item 2 of argv) with title (item 1 of argv)\nend run"
            command = ["/usr/bin/osascript", "-e", script, title, message]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            log.warning("notification failed: %s", result.stderr.strip())
