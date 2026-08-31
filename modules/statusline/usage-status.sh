#!/usr/bin/env bash
# Plan-usage statusline widget.
#
# ccstatusline's built-in session-usage/weekly-usage widgets poll
# /api/oauth/usage on a 180s cache. That endpoint re-arms its backoff on every
# request made while already blocked, so the built-ins keep themselves
# throttled and render "[Rate limited]" indefinitely.
#
# This reads the window straight off the statusline payload instead. API-key
# sessions carry no rate_limits there, so fall back to a snapshot refreshed at
# most hourly by a detached helper — the render itself never waits on network.
set -uo pipefail

state="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage/state.json"
payload=$(cat)

if [ "$(@jq@ -r '.rate_limits // "null"' <<<"$payload")" = "null" ]; then
  @refresh@ "$state" >/dev/null 2>&1 </dev/null &
  if [ -s "$state" ]; then
    payload=$(@jq@ -c --slurpfile s "$state" \
      '. + {cached_rate_limits: ($s[0].rate_limits // null)}' <<<"$payload" \
      2>/dev/null || printf '%s' "$payload")
  fi
fi

printf '%s' "$payload" | @jq@ -rj -f @filter@
