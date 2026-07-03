#!/usr/bin/env bash
# Refresh marketplace indexes after Nix rebuilds change store paths.
# Consumes the .nix-refresh-needed marker written by verify-cache-integrity.sh.
# Best-effort: failures rewrite the marker for next-session retry.

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
