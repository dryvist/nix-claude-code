#!/usr/bin/env bash
# Regression test for modules/hooks/marketplace-refresh.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   HOOK  store path of the hook script under test
#   out   file to write the success marker to
#
# A stub `claude` on PATH keeps the check hermetic: it logs every call, answers
# `plugin list --json` with $PLUGIN_LIST_JSON, and fails `plugin update` when
# $FAIL_UPDATE is set.

set -euo pipefail

fakebin="$(mktemp -d)"
# Resolve bash by path before shadowing PATH: the Nix Linux sandbox has no
# /usr/bin/env, so a `#!/usr/bin/env bash` stub is not executable there.
bash_bin="$(command -v bash)"
export PATH="$fakebin:$PATH"

cat >"$fakebin/claude" <<EOF
#!$bash_bin
echo "called \$*" >>"\${CLAUDE_CALL_LOG}"
[ "\$1 \$2" = "plugin list" ] && printf '%s' "\${PLUGIN_LIST_JSON}"
[ "\$1 \$2" = "plugin update" ] && [ -n "\${FAIL_UPDATE:-}" ] && exit 1
exit 0
EOF
chmod +x "$fakebin/claude"

export PLUGIN_LIST_JSON='[{"id":"p@testmp","enabled":true},{"id":"off@testmp","enabled":false},{"id":"q@other","enabled":true}]'

marker_path() {
  echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/.nix-refresh-needed"
}

setup_case() {
  HOME="$(mktemp -d)"
  export HOME
  mkdir -p "$(dirname "$(marker_path)")"
  printf 'timestamp=2026-01-01T00:00:00Z\nmarketplace=testmp\n' >"$(marker_path)"
  CLAUDE_CALL_LOG="$HOME/claude-calls.log"
  export CLAUDE_CALL_LOG
  : >"$CLAUDE_CALL_LOG"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# --- Case 1: updates enabled plugins of the queued marketplace only ----------
setup_case
bash "$HOOK" || fail "hook exited non-zero"
grep -q "called plugin update p@testmp" "$CLAUDE_CALL_LOG" ||
  fail "enabled plugin of the queued marketplace was not updated"
grep -q "plugin update off@testmp" "$CLAUDE_CALL_LOG" && fail "disabled plugin was updated"
grep -q "plugin update q@other" "$CLAUDE_CALL_LOG" && fail "plugin of an unqueued marketplace was updated"
# `marketplace update` always fails on a Nix-linked marketplace; calling it
# blocked every update.
grep -q "marketplace update" "$CLAUDE_CALL_LOG" && fail "hook called marketplace update"
[[ -f "$(marker_path)" ]] && fail "marker left behind after a successful update"

# --- Case 2: no marker -> no-op ----------------------------------------------
setup_case
rm -f "$(marker_path)"
bash "$HOOK" || fail "hook exited non-zero with no marker"
[[ -s $CLAUDE_CALL_LOG ]] && fail "hook invoked claude with no marker present"

# --- Case 3: failed update -> marker re-queued for next session --------------
setup_case
FAIL_UPDATE=1 bash "$HOOK" || fail "hook exited non-zero on a failed update"
grep -qx "marketplace=testmp" "$(marker_path)" || fail "failed update was not re-queued"

# --- Case 4: custom CLAUDE_CONFIG_DIR -> marker read from the relocated tree -
setup_case
rm -f "$(marker_path)"
export CLAUDE_CONFIG_DIR="$HOME/xdg/claude"
mkdir -p "$(dirname "$(marker_path)")"
printf 'marketplace=testmp\n' >"$(marker_path)"
bash "$HOOK" || fail "hook exited non-zero with a custom CLAUDE_CONFIG_DIR"
grep -q "plugin update p@testmp" "$CLAUDE_CALL_LOG" ||
  fail "hook ignored the marker under a custom CLAUDE_CONFIG_DIR"
[[ -f "$(marker_path)" ]] && fail "relocated marker left behind"
unset CLAUDE_CONFIG_DIR

# --- Case 5: concurrent sessions -> the marker is claimed exactly once -------
setup_case
bash "$HOOK" &
p1=$!
bash "$HOOK" &
p2=$!
wait "$p1" || fail "concurrent run 1 exited non-zero"
wait "$p2" || fail "concurrent run 2 exited non-zero"
n=$(grep -c "plugin update p@testmp" "$CLAUDE_CALL_LOG" || true)
[[ $n -eq 1 ]] || fail "plugins updated $n times concurrently — marker not claimed atomically"

# --- Case 6: no claim or temp file is left behind ----------------------------
leftovers=$(find "$(dirname "$(marker_path)")" -name '*.claimed.*' -o -name '*.failures.*' | wc -l | tr -d ' ')
[[ ${leftovers:-0} -eq 0 ]] || fail "hook left $leftovers claim/temp file(s) behind"

echo "marketplace-refresh: all cases passed" >"${out:-/dev/stdout}"
