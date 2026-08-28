#!/usr/bin/env bash
# Regression test for modules/hooks/marketplace-refresh.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   HOOK  store path of the hook script under test
#   out   file to write the success marker to
#
# The property under test: the hook must not reinstall plugins while other
# Claude Code sessions are live. `claude plugin install` replaces version-pinned
# cache directories and rewrites the shared installed_plugins.json, and every
# session resolves its plugin and hook paths once at startup — so refreshing
# under a peer session breaks every hook in that session at once, Stop included,
# which cannot be recovered without restarting it.
#
# Stub `pgrep` and `claude` on PATH keep the check hermetic: no real process
# table is consulted and no real plugin is ever installed.

set -euo pipefail

fakebin="$(mktemp -d)"
export PATH="$fakebin:$PATH"

# Stub claude: records that it was called at all. Any invocation while peers are
# live is the bug this test exists to catch.
cat >"$fakebin/claude" <<'EOF'
#!/usr/bin/env bash
echo "called $*" >>"${CLAUDE_CALL_LOG}"
exit 0
EOF
chmod +x "$fakebin/claude"

# Stub pgrep: prints one fake pid per session named by SESSION_COUNT, so the
# hook's `pgrep -x claude | wc -l` sees exactly that many.
cat >"$fakebin/pgrep" <<'EOF'
#!/usr/bin/env bash
i=0
while [ "$i" -lt "${SESSION_COUNT:-0}" ]; do
  echo $((1000 + i))
  i=$((i + 1))
done
EOF
chmod +x "$fakebin/pgrep"

# Fresh HOME with a refresh marker queued, per case.
setup_case() {
  HOME="$(mktemp -d)"
  export HOME
  mkdir -p "$HOME/.claude/plugins/cache"
  printf 'timestamp=2026-01-01T00:00:00Z\nmarketplace=testmp\n' \
    >"$HOME/.claude/plugins/cache/.nix-refresh-needed"
  CLAUDE_CALL_LOG="$HOME/claude-calls.log"
  export CLAUDE_CALL_LOG
  : >"$CLAUDE_CALL_LOG"
}

marker_path() { echo "$HOME/.claude/plugins/cache/.nix-refresh-needed"; }

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# --- Case 1: peer sessions live -> defer, touch nothing, keep the marker ------
setup_case
SESSION_COUNT=3 bash "$HOOK" || fail "hook exited non-zero when deferring"

if [[ -s $CLAUDE_CALL_LOG ]]; then
  fail "hook invoked claude while 3 sessions were live: $(cat "$CLAUDE_CALL_LOG")"
fi
[[ -f "$(marker_path)" ]] ||
  fail "hook consumed the marker while deferring — the refresh would never retry"

# --- Case 2: only this session -> proceed and consume the marker -------------
setup_case
SESSION_COUNT=1 bash "$HOOK" || fail "hook exited non-zero on the solo path"

grep -q "marketplace update testmp" "$CLAUDE_CALL_LOG" ||
  fail "hook did not refresh the marketplace when it was the only session"
[[ -f "$(marker_path)" ]] &&
  fail "hook left the marker behind after a successful refresh"

# --- Case 3: no marker -> no-op regardless of session count ------------------
setup_case
rm -f "$(marker_path)"
SESSION_COUNT=1 bash "$HOOK" || fail "hook exited non-zero with no marker"
[[ -s $CLAUDE_CALL_LOG ]] && fail "hook invoked claude with no marker present"

echo "marketplace-refresh session guard: all cases passed" >"${out:-/dev/stdout}"
