#!/usr/bin/env bash
# Remove real directories left over from the one-time migration from
# recursive=true to directory symlinks. Marketplace directory-symlinks and
# component dirs are left to home-manager, which relinks idempotently —
# pre-emptively removing HM-owned symlinks here only churned ~24 marketplace
# symlinks on every activation.
# Usage (sourced): . this-script dir1 dir2 ...
# Requires: DRY_RUN_CMD from activation scope.

# Requires: log_info, log_warn from cleanup-common.sh (sourced by caller)

for dir in "$@"; do
  # Only genuine real directories (not symlinks-to-dirs). `! -L` keeps
  # HM-managed marketplace symlinks untouched — home-manager owns them.
  # Component dirs (commands, agents, skills) hold per-file symlinks and may
  # contain user-created content, so only the marketplaces path is removed.
  if [ -d "$dir" ] && [ ! -L "$dir" ]; then
    case "$dir" in
    */.claude/plugins/marketplaces/*)
      if $DRY_RUN_CMD rm -rf "$dir"; then
        log_info "Removed real directory (migration to directory symlink): $dir"
      else
        log_warn "Failed to remove real directory: $dir"
      fi
      ;;
    esac
  fi
done
