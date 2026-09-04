#!/usr/bin/env bash
# Remove real directories left over from the one-time migration from
# recursive=true to directory symlinks. Marketplace directory-symlinks and
# component dirs are left to home-manager, which relinks idempotently —
# pre-emptively removing HM-owned symlinks here only churned ~24 marketplace
# symlinks on every activation.
# Usage (sourced): . this-script dir1 dir2 ...
# Requires: DRY_RUN_CMD from activation scope.
# Requires: MARKETPLACES_GLOB from activation scope — a case pattern
# (e.g. "*/.claude/plugins/marketplaces/*") matching the marketplaces path
# under the caller's configured config dir. Falls back to the upstream
# default so a caller that doesn't set it (or an older activation script
# still holding this file open across an upgrade) keeps today's behavior.

# Requires: log_info, log_warn from cleanup-common.sh (sourced by caller)

MARKETPLACES_GLOB="${MARKETPLACES_GLOB:-*/.claude/plugins/marketplaces/*}"

for dir in "$@"; do
  # Only genuine real directories (not symlinks-to-dirs). `! -L` keeps
  # HM-managed marketplace symlinks untouched — home-manager owns them.
  # Component dirs (commands, agents, skills) hold per-file symlinks and may
  # contain user-created content, so only the marketplaces path is removed.
  if [ -d "$dir" ] && [ ! -L "$dir" ]; then
    # shellcheck disable=SC2254 # intentionally unquoted: MARKETPLACES_GLOB
    # is a dynamic case pattern (contains `*`), not a literal to match.
    case "$dir" in
    $MARKETPLACES_GLOB)
      if $DRY_RUN_CMD rm -rf "$dir"; then
        log_info "Removed real directory (migration to directory symlink): $dir"
      else
        log_warn "Failed to remove real directory: $dir"
      fi
      ;;
    esac
  fi
done
