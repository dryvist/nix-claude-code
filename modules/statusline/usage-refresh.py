"""Refresh the cached plan-usage snapshot, at most once an hour.

Runs detached from the statusline render, which has a sub-second budget and
must never block on the network. Writes an atomic JSON state file:

    {"fetched_at": epoch, "blocked_until": epoch, "rate_limits": {...}}

`/api/oauth/usage` re-arms its backoff on every request made while already
blocked, so a caller that retries on the old cadence keeps itself throttled
forever. Two rules follow, and both are load-bearing:

  * never send a request before `blocked_until`;
  * claim the attempt by writing `fetched_at` *before* the request, so
    concurrent renders across sessions do not stampede.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

MIN_INTERVAL = 3600
DEFAULT_BACKOFF = 3600
KEYCHAIN_SERVICE = "Claude Code-credentials"
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"


def read_state(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def write_state(path, state):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(state, fh)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def read_token():
    """Claude Code's own OAuth token, the same one ccstatusline reads.

    Held in memory for the one request and never written to the cache.
    """
    try:
        raw = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout
        return json.loads(raw).get("claudeAiOauth", {}).get("accessToken") or ""
    except (OSError, ValueError, subprocess.SubprocessError):
        return ""


def retry_after(headers):
    raw = (headers.get("retry-after") or "").strip()
    if raw.isdigit():
        return max(int(raw), 0) or DEFAULT_BACKOFF
    return DEFAULT_BACKOFF


def buckets(payload):
    """Map an API response onto the statusline payload's rate_limits shape.

    Accepts either flat `five_hour`/`seven_day` objects or a `limits` list,
    since the endpoint has served both.
    """
    out = {}
    for key in ("five_hour", "seven_day"):
        bucket = payload.get(key)
        if isinstance(bucket, dict):
            out[key] = bucket
    for limit in payload.get("limits") or []:
        if not isinstance(limit, dict):
            continue
        name = str(limit.get("type") or limit.get("name") or "").lower()
        for key, needles in (
            ("five_hour", ("five_hour", "5h", "session")),
            ("seven_day", ("seven_day", "7d", "week")),
        ):
            if key not in out and any(n in name for n in needles):
                out[key] = limit
    return out


def main():
    path = sys.argv[1]
    now = int(time.time())
    state = read_state(path)

    if now < state.get("blocked_until", 0):
        return 0
    if now - state.get("fetched_at", 0) < MIN_INTERVAL:
        return 0

    # Claim the attempt before sending it, so parallel renders skip.
    state["fetched_at"] = now
    write_state(path, state)

    token = read_token()
    if not token:
        return 0

    request = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as err:
        if err.code == 429:
            state["blocked_until"] = now + retry_after(err.headers)
        write_state(path, state)
        return 0
    except (OSError, ValueError):
        return 0

    if isinstance(payload, dict):
        found = buckets(payload)
        if found:
            state["rate_limits"] = found
            state["blocked_until"] = 0
            write_state(path, state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
