#!/usr/bin/env bash
# Remove symlinks that point into a home-manager-files store path belonging
# to a previous generation. The broken-symlink pass misses these: the old
# store path survives until garbage collection, so the link still resolves,
# but home-manager no longer tracks it and linkGeneration never removes it.
# Usage (sourced): . this-script type1 dir1 type2 dir2 ...
# Requires: DRY_RUN_CMD, newGenPath from activation scope.

# Requires: log_info, log_warn from cleanup-common.sh (sourced by caller)

current_files=$(readlink "${newGenPath:-}/home-files" 2>/dev/null || true)

if [ -z "$current_files" ]; then
  log_warn 'Skipping stale-generation cleanup: cannot resolve $newGenPath/home-files'
else
  while [ $# -ge 2 ]; do
    type_name="$1"
    dir="$2"
    shift 2
    if [ -d "$dir" ]; then
      find "$dir" -maxdepth 1 -type l -print0 | while IFS= read -d $'\0' -r link; do
        target=$(readlink "$link")
        case "$target" in
        "$current_files"/*) ;;
        /nix/store/*-home-manager-files/*)
          if $DRY_RUN_CMD rm "$link"; then
            log_info "Removed stale-generation ${type_name}: $(basename "$link")"
          else
            log_warn "Failed to remove stale-generation ${type_name}: $(basename "$link")"
          fi
          ;;
        esac
      done
    fi
  done
fi
