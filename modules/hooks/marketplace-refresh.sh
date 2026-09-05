#!/usr/bin/env bash
# Refresh marketplace indexes after Nix rebuilds change store paths.
# Consumes the .nix-refresh-needed marker written by verify-cache-integrity.sh.
# Best-effort: an update failure OR an incomplete reinstall rewrites the marker
# for next-session retry.

set -euo pipefail

# Anchored at the same config tree Nix writes to. `verify-cache-integrity.sh`
# writes this marker under `programs.claude.configDir`; with a custom
# configDir the module exports CLAUDE_CONFIG_DIR to match (see
# options-runtime.nix), so honoring it here keeps producer and consumer in
# sync. Falls back to upstream's default when the env var is unset.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MARKER="${CLAUDE_DIR}/plugins/cache/.nix-refresh-needed"
[[ -f $MARKER ]] || exit 0

log_info() { echo "[marketplace-refresh] $1" >&2; }

# Claim the marker by renaming it. rename(2) is atomic, so when several
# sessions start at once exactly one wins and the losers find nothing and
# exit — without this they would all reinstall the same plugins concurrently
# and race each other writing the shared installed_plugins.json. The old
# sole-session guard used to serialize this as a side effect; claiming does
# it deliberately and without blocking the repair.
WORK="${MARKER}.claimed.$$"
mv "$MARKER" "$WORK" 2>/dev/null || exit 0

# No session guard. Reinstalling is additive and Claude Code protects itself:
# `claude plugin install` writes a new version directory beside the old one, and
# when a version directory would be overwritten or relinked in place it checks
# the per-version .in_use/<pid> refcount and defers ("in use by another session;
# deferring overwrite until it exits" / "deferring the relink until it exits").
# A peer session's directory therefore cannot be pulled out from under it.
#
# This used to defer unless it was the sole session (`pgrep -x claude` counting
# 1). That was guarding against verify-cache-integrity.sh's rm -rf of the whole
# marketplace cache, which is gone. The guard made the repair unreachable on any
# machine that keeps more than one session open — which is the only kind that
# hits the problem — so the marker was queued indefinitely and every plugin with
# a dangling installPath stayed broken until a manual /reload-plugins.

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
  log_info "Refreshing marketplace index: $mp"
  # No timeout — claude plugin marketplace update has its own network timeout.
  if claude plugin marketplace update "$mp" >/dev/null 2>&1; then
    # `marketplace update` refreshes the index but does NOT re-resolve installed
    # plugins, so each keeps an installPath pointing at the pre-rebuild cache dir
    # that verify-cache-integrity just purged. Claude then skips the plugin at
    # startup until a manual /reload-plugins. Reinstall — from the local,
    # Nix-managed marketplace — only the enabled plugins whose installPath is now
    # gone, letting Claude natively re-point its own installed_plugins.json.
    if command -v jq >/dev/null 2>&1; then
      while IFS=$'\t' read -r plugin_id install_path; do
        [[ -n $plugin_id ]] || continue
        [[ -e $install_path ]] && continue
        claude plugin install "$plugin_id" >/dev/null 2>&1 || true
      done < <(claude plugin list --json 2>/dev/null |
        jq -r --arg mp "$mp" '.[]? | select(.enabled and (.id | type == "string" and endswith("@" + $mp))) | [.id, .installPath] | @tsv' 2>/dev/null)

      # Re-scan after the reinstall attempt: if any enabled plugin for this
      # marketplace still points at a missing installPath, the reinstall did not
      # take (transient install failure). Re-queue the marketplace so the next
      # session retries — otherwise the marker is cleared below and the plugin
      # stays broken with no retry.
      # ponytail: unbounded retry if a plugin is permanently removed upstream;
      # acceptable — best-effort, next-session cadence, same ceiling the existing
      # marketplace-update-failure path already accepts.
      # Wrap the substitution in `if` so a transient `claude`/`jq` failure is
      # caught (and re-queued) instead of tripping `set -e` and aborting the
      # whole loop before the remaining marketplaces are processed.
      if still_missing=$(claude plugin list --json 2>/dev/null |
        jq -r --arg mp "$mp" '.[]? | select(.enabled and (.id | type == "string" and endswith("@" + $mp))) | .installPath // empty' 2>/dev/null |
        while IFS= read -r p; do [[ -n $p && ! -e $p ]] && echo x || :; done | wc -l | tr -d ' '); then
        if [[ ${still_missing:-0} -gt 0 ]]; then
          log_info "Reinstall incomplete: $mp ($still_missing plugin(s) unresolved) — will retry next session"
          echo "marketplace=$mp" >>"$failures_tmp"
        fi
      else
        log_info "Re-scan failed for $mp — will retry next session"
        echo "marketplace=$mp" >>"$failures_tmp"
      fi
    fi
  else
    log_info "Failed: $mp (will retry next session)"
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
