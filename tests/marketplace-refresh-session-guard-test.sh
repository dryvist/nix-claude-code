#!/usr/bin/env bash
# Regression test for modules/hooks/marketplace-refresh.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   HOOK  store path of the hook script under test
#   out   file to write the success marker to
#
# The property under test: the hook refreshes REGARDLESS of how many Claude Code
# sessions are live. It used to defer unless it was the sole session, which made
# the repair unreachable on any machine that keeps more than one session open —
# the marker was queued forever and every plugin with a dangling installPath
# stayed broken. That guard existed to protect peers from
# verify-cache-integrity.sh's rm -rf, which no longer exists; Claude Code itself
# refuses to overwrite or relink a version directory a peer holds via .in_use.
#
# A dangling installPath is in any case recoverable in-session with
# /reload-plugins — it does not require restarting the session.
#
# Stub `pgrep` and `claude` on PATH keep the check hermetic: no real process
# table is consulted and no real plugin is ever installed.

set -euo pipefail

fakebin="$(mktemp -d)"

# Resolve bash by path before shadowing PATH. The Nix Linux sandbox has no
# /usr/bin/env, so a `#!/usr/bin/env bash` stub is not executable there —
# darwin's looser sandbox hides that.
bash_bin="$(command -v bash)"
export PATH="$fakebin:$PATH"

# Stub claude: records that it was called at all. Any invocation while peers are
# live is the bug this test exists to catch.
cat >"$fakebin/claude" <<EOF
#!$bash_bin
echo "called \$*" >>"\${CLAUDE_CALL_LOG}"
exit 0
EOF
chmod +x "$fakebin/claude"

# Stub pgrep: prints one fake pid per session named by SESSION_COUNT, so the
# hook's `pgrep -x claude | wc -l` sees exactly that many. Exits 1 when it finds
# nothing, exactly as the real pgrep does — that non-zero is what the hook's
# `|| true` has to absorb.
cat >"$fakebin/pgrep" <<EOF
#!$bash_bin
i=0
while [ "\$i" -lt "\${SESSION_COUNT:-0}" ]; do
  echo \$((1000 + i))
  i=\$((i + 1))
done
[ "\${SESSION_COUNT:-0}" -gt 0 ]
EOF
chmod +x "$fakebin/pgrep"

# Fresh HOME with a refresh marker queued, per case. When CLAUDE_CONFIG_DIR is
# exported (custom `programs.claude.configDir`), the marker lives under it
# instead of $HOME/.claude — the hook has to follow the same env var the
# module exports, or a relocated cache never gets refreshed.
setup_case() {
  HOME="$(mktemp -d)"
  export HOME
  mkdir -p "$(dirname "$(marker_path)")"
  printf 'timestamp=2026-01-01T00:00:00Z\nmarketplace=testmp\n' \
    >"$(marker_path)"
  CLAUDE_CALL_LOG="$HOME/claude-calls.log"
  export CLAUDE_CALL_LOG
  : >"$CLAUDE_CALL_LOG"
}

marker_path() {
  echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/.nix-refresh-needed"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# --- Case 1: peer sessions live -> still refresh, still consume the marker ----
# The regression this guards: deferring here left the marker queued forever on a
# machine that always has peers, so a dangling installPath was never repaired.
setup_case
SESSION_COUNT=3 bash "$HOOK" || fail "hook exited non-zero with peer sessions live"

grep -q "marketplace update testmp" "$CLAUDE_CALL_LOG" ||
  fail "hook deferred with 3 sessions live — the repair never runs on a busy machine"
[[ -f "$(marker_path)" ]] &&
  fail "hook left the marker behind after a successful refresh"

# --- Case 2: solo session -> proceed and consume the marker ------------------
setup_case
SESSION_COUNT=1 bash "$HOOK" || fail "hook exited non-zero on the solo path"

grep -q "marketplace update testmp" "$CLAUDE_CALL_LOG" ||
  fail "hook did not refresh the marketplace on the solo path"
[[ -f "$(marker_path)" ]] &&
  fail "hook left the marker behind after a successful refresh"

# --- Case 3: pgrep matches nothing -> still refresh, never abort -------------
# The hook no longer consults pgrep at all; this pins that a process table
# reporting zero sessions cannot resurrect a deferral or abort the hook.
setup_case
SESSION_COUNT=0 bash "$HOOK" || fail "hook aborted when pgrep matched nothing"

grep -q "marketplace update testmp" "$CLAUDE_CALL_LOG" ||
  fail "hook skipped the refresh when pgrep reported no sessions"

# --- Case 4: no marker -> no-op regardless of session count ------------------
setup_case
rm -f "$(marker_path)"
SESSION_COUNT=1 bash "$HOOK" || fail "hook exited non-zero with no marker"
[[ -s $CLAUDE_CALL_LOG ]] && fail "hook invoked claude with no marker present"

# --- Case 5: custom CLAUDE_CONFIG_DIR -> marker read from the relocated tree -
# The module exports CLAUDE_CONFIG_DIR whenever configDir is customized; the
# hook must consume the marker from there, not from a hard-coded $HOME/.claude.
setup_case
rm -f "$HOME/.claude/plugins/cache/.nix-refresh-needed"
export CLAUDE_CONFIG_DIR="$HOME/xdg/claude"
# Only the relocated tree holds a marker — $HOME/.claude/... does not exist.
mkdir -p "$(dirname "$(marker_path)")"
printf 'timestamp=2026-01-01T00:00:00Z\nmarketplace=testmp\n' >"$(marker_path)"
SESSION_COUNT=1 bash "$HOOK" || fail "hook exited non-zero with a custom CLAUDE_CONFIG_DIR"
grep -q "marketplace update testmp" "$CLAUDE_CALL_LOG" ||
  fail "hook ignored the marker under a custom CLAUDE_CONFIG_DIR"
[[ -f "$(marker_path)" ]] &&
  fail "hook left the relocated marker behind after a successful refresh"
unset CLAUDE_CONFIG_DIR

# --- Case 6: concurrent sessions -> the marker is claimed exactly once -------
# Reinstalling concurrently would have several sessions racing each other
# writing the shared installed_plugins.json. The hook claims the marker with an
# atomic rename, so whichever interleaving occurs, exactly one run refreshes.
setup_case
SESSION_COUNT=3 bash "$HOOK" &
p1=$!
SESSION_COUNT=3 bash "$HOOK" &
p2=$!
wait "$p1" || fail "concurrent run 1 exited non-zero"
wait "$p2" || fail "concurrent run 2 exited non-zero"

n=$(grep -c "marketplace update testmp" "$CLAUDE_CALL_LOG" || true)
[[ $n -eq 1 ]] ||
  fail "marketplace refreshed $n times concurrently — the marker was not claimed atomically"
[[ -f "$(marker_path)" ]] && fail "marker survived a successful concurrent refresh"

# --- Case 7: no claim file is left behind ------------------------------------
# A leaked .claimed.<pid> would strand the marker: the next session sees no
# marker and never retries.
leftovers=$(find "$(dirname "$(marker_path)")" -name '*.claimed.*' -o -name '*.failures.*' 2>/dev/null | wc -l | tr -d ' ')
[[ ${leftovers:-0} -eq 0 ]] ||
  fail "hook left $leftovers claim/temp file(s) behind in the cache dir"

echo "marketplace-refresh session guard: all cases passed" >"${out:-/dev/stdout}"
