#!/usr/bin/env bash
# Refresh marketplace indexes after Nix rebuilds change store paths.
# Consumes the .nix-refresh-needed marker written by verify-cache-integrity.sh.
# Best-effort: an update failure OR an incomplete reinstall rewrites the marker
# for next-session retry.

set -euo pipefail

MARKER="${HOME}/.claude/plugins/cache/.nix-refresh-needed"
[[ -f $MARKER ]] || exit 0

log_info() { echo "[marketplace-refresh] $1" >&2; }

failures_tmp="$(mktemp "${MARKER}.failures.XXXXXX")"
trap 'rm -f "$failures_tmp"' EXIT
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
done <"$MARKER"

if grep -q "^marketplace=" "$failures_tmp"; then
  mv "$failures_tmp" "$MARKER"
  log_info "Partial refresh — some marketplace(s) queued for next session"
else
  rm -f "$MARKER"
  log_info "All marketplace indexes refreshed"
fi
