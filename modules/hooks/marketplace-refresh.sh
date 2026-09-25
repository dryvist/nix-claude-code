#!/usr/bin/env bash
# Update installed plugins after a Nix rebuild moves a marketplace.
# Consumes the .nix-refresh-needed marker written by verify-cache-integrity.sh;
# a failed update rewrites it for next-session retry.

set -euo pipefail

# Anchored at the same config tree Nix writes to. `verify-cache-integrity.sh`
# writes this marker under `programs.claude.configDir`; with a custom
# configDir the module exports CLAUDE_CONFIG_DIR to match (see
# options-runtime.nix), so honoring it here keeps producer and consumer in
# sync. Falls back to upstream's default when the env var is unset.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MARKER="${CLAUDE_DIR}/plugins/cache/.nix-refresh-needed"
[[ -f $MARKER ]] || exit 0
# Leave the marker queued until jq is on PATH; without it no plugin is listed.
command -v jq >/dev/null 2>&1 || exit 0

log_info() { echo "[marketplace-refresh] $1" >&2; }

# Claim the marker by renaming it. rename(2) is atomic, so when several
# sessions start at once exactly one wins and the losers find nothing and
# exit instead of racing each other on installed_plugins.json.
WORK="${MARKER}.claimed.$$"
mv "$MARKER" "$WORK" 2>/dev/null || exit 0

# No session guard. Updating is additive and Claude Code protects itself:
# `claude plugin update` writes a new version directory beside the old one, and
# when a version directory would be overwritten or relinked in place it checks
# the per-version .in_use/<pid> refcount and defers ("in use by another session;
# deferring overwrite until it exits" / "deferring the relink until it exits").
# A peer session's directory therefore cannot be pulled out from under it.

failures_tmp="$(mktemp "${MARKER}.failures.XXXXXX")"
# Hand the claim back if we die before consuming it, so the marker is not lost
# and the next session retries. Both success paths drop $WORK first, so this
# only fires on an abnormal exit.
cleanup() {
  rm -f "$failures_tmp"
  [[ -f $WORK ]] && mv "$WORK" "$MARKER" 2>/dev/null
  return 0
}
trap cleanup EXIT
echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$failures_tmp"

while IFS='=' read -r key value; do
  [[ $key == "marketplace" ]] || continue
  mp="$value"
  # No `claude plugin marketplace update`: it always fails for a Nix-linked
  # marketplace ("corrupted installLocation"), and is unnecessary — Claude reads
  # the index through the symlink. `claude plugin update` installs a new version
  # dir beside the old one, so sessions still using the old one keep it.
  log_info "Updating plugins from: $mp"
  failed=false
  while IFS= read -r plugin_id; do
    [[ -n $plugin_id ]] || continue
    claude plugin update "$plugin_id" >/dev/null 2>&1 || failed=true
  done < <(claude plugin list --json 2>/dev/null |
    jq -r --arg mp "$mp" '.[]? | select(.enabled and (.id | type == "string" and endswith("@" + $mp))) | .id' 2>/dev/null)
  if [[ $failed == true ]]; then
    log_info "Update failed: $mp (will retry next session)"
    echo "marketplace=$mp" >>"$failures_tmp"
  fi
done <"$WORK"

# Release the claim before writing the marker back, or the EXIT trap would
# restore the stale claimed copy over the failures we just recorded.
rm -f "$WORK"

if grep -q "^marketplace=" "$failures_tmp"; then
  mv "$failures_tmp" "$MARKER"
  log_info "Partial refresh — some marketplace(s) queued for next session"
else
  log_info "All marketplace indexes refreshed"
fi
