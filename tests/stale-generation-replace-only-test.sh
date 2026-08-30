#!/usr/bin/env bash
# Regression test for modules/scripts/cleanup-stale-generation-symlinks.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   SCRIPT  store path of the cleanup script under test
#   COMMON  store path of cleanup-common.sh (logging helpers)
#   out     file to write the success marker to
#
# The property under test: stale-generation cleanup is REPLACE-ONLY. A link
# into a previous generation's home-manager-files path is removed only when
# the new generation carries the same relative path. A generation that does
# not carry the component (a rebuild from another branch/worktree/pin) must
# keep still-resolving links — deleting them wiped every deployed skill and
# command for live sessions.

set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

# Fixture "store": one old generation, one new generation. The script's store
# pattern is overridable via HM_FILES_STORE_GLOB precisely so this test can
# stand in a tmpdir; the suffix must still end in -home-manager-files.
store="$root/store"
old_gen="$store/aaaa-home-manager-files"
new_gen_files="$store/bbbb-home-manager-files"
mkdir -p "$old_gen/.claude/skills" "$new_gen_files/.claude/skills"
echo old >"$old_gen/.claude/skills/kept-and-replaced"
echo new >"$new_gen_files/.claude/skills/kept-and-replaced"
echo old-only >"$old_gen/.claude/skills/foreign-only"

# newGenPath/home-files -> the new generation's files root.
new_gen="$root/generation"
mkdir -p "$new_gen"
ln -s "$new_gen_files" "$new_gen/home-files"

# Component dir with the four cases.
dir="$root/home/.claude/skills"
mkdir -p "$dir"
ln -s "$old_gen/.claude/skills/kept-and-replaced" "$dir/kept-and-replaced" # (a) replaced -> removed
ln -s "$old_gen/.claude/skills/foreign-only" "$dir/foreign-only"           # (b) not in new gen -> kept
ln -s "$new_gen_files/.claude/skills/kept-and-replaced" "$dir/current"     # (c) current gen -> untouched
echo unmanaged >"$root/unmanaged-target"
ln -s "$root/unmanaged-target" "$dir/unmanaged" # (d) non-HM link -> untouched

log="$root/log"
run_cleanup() {
  (
    # Activation scope the script expects.
    DRY_RUN_CMD=""
    newGenPath="$new_gen"
    HM_FILES_STORE_GLOB="$store/*-home-manager-files"
    export HM_FILES_STORE_GLOB
    # shellcheck disable=SC1090
    . "$COMMON"
    # shellcheck disable=SC1090
    . "$SCRIPT" skill "$dir"
  ) 2>>"$log"
}

run_cleanup

fail() {
  echo "FAIL: $1" >&2
  cat "$log" >&2
  exit 1
}

[ ! -e "$dir/kept-and-replaced" ] || fail "replaced stale link was not removed"
[ -L "$dir/foreign-only" ] || fail "foreign-generation link was deleted (the wipe bug)"
[ -L "$dir/current" ] || fail "current-generation link was touched"
[ -L "$dir/unmanaged" ] || fail "non-home-manager link was touched"
grep -q "Kept still-resolving skill: foreign-only" "$log" || fail "kept-link warning not logged"
grep -q "Removed stale-generation skill: kept-and-replaced" "$log" || fail "removal not logged"

# Idempotence: a second run changes nothing further and keeps the same set.
run_cleanup
[ -L "$dir/foreign-only" ] || fail "second run deleted the foreign-generation link"

echo ok >"${out:-$root/out}"
echo "stale-generation replace-only: all cases pass"
