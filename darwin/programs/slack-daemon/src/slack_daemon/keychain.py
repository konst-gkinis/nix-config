"""Secrets in the macOS login Keychain, through /usr/bin/security.

Writes go through `security -i` on stdin, so the secret never appears in a
process list; values are base64-encoded to sidestep its quoting rules."""

from __future__ import annotations

import base64
import getpass
import subprocess

SECURITY = "/usr/bin/security"
SLACK_SERVICE = "slack-daemon.slack-session"


def read(service: str) -> str | None:
    result = subprocess.run(
        [SECURITY, "find-generic-password", "-s", service, "-a", getpass.getuser(), "-w"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return value or None


def read_b64(service: str) -> str | None:
    value = read(service)
    return base64.b64decode(value).decode() if value else None


def write_b64(service: str, secret: str) -> None:
    encoded = base64.b64encode(secret.encode()).decode()
    command = f'add-generic-password -U -s {service} -a {getpass.getuser()} -w "{encoded}"\n'
    subprocess.run([SECURITY, "-i"], input=command, text=True, check=True, capture_output=True)


def delete(service: str) -> None:
    subprocess.run(
        [SECURITY, "delete-generic-password", "-s", service, "-a", getpass.getuser()],
        capture_output=True,
    )

