#!/usr/bin/env bash
# Remove symlinks that point into a home-manager-files store path belonging
# to a previous generation. The broken-symlink pass misses these: the old
# store path survives until garbage collection, so the link still resolves,
# but home-manager no longer tracks it and linkGeneration never removes it.
#
# Replace-only guard: a stale-generation link is deleted ONLY when the new
# generation carries the same relative path (linkGeneration has already laid
# down the replacement). A generation that does NOT carry the component —
# a rebuild from another branch, worktree, or pin — must never delete
# still-working links: that wiped every skill/command for live sessions.
# Such links are kept and logged so the foreign-generation rebuild is
# visible without being destructive.
# Usage (sourced): . this-script type1 dir1 type2 dir2 ...
# Requires: DRY_RUN_CMD, newGenPath from activation scope.
# Optional: HM_FILES_STORE_GLOB overrides the home-manager-files path
# pattern (tests inject a fixture prefix; defined once, used everywhere).

# Requires: log_info, log_warn from cleanup-common.sh (sourced by caller)

current_files=$(readlink "${newGenPath:-}/home-files" 2>/dev/null || true)
hm_files_glob="${HM_FILES_STORE_GLOB:-/nix/store/*-home-manager-files}"

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
        # shellcheck disable=SC2254  # glob expansion in case pattern is intended
        $hm_files_glob/*)
          # Relative path inside the old generation's home-manager-files
          # root: strip everything up to and including the store dir. The
          # replacement must exist at the same relative path in the new
          # generation for the delete to be safe.
          rel=${target#"${target%%-home-manager-files/*}"-home-manager-files/}
          if [ -e "$current_files/$rel" ]; then
            if $DRY_RUN_CMD rm "$link"; then
              log_info "Removed stale-generation ${type_name}: $(basename "$link")"
            else
              log_warn "Failed to remove stale-generation ${type_name}: $(basename "$link")"
            fi
          else
            log_warn "Kept still-resolving ${type_name}: $(basename "$link") (new generation does not carry it — foreign-generation rebuild?)"
          fi
          ;;
        esac
      done
    fi
  done
fi
