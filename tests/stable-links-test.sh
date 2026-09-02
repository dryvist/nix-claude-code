#!/usr/bin/env bash
# Regression test for modules/scripts/stable-links.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   SCRIPT  store path of the linker under test
#   out     file to write the success marker to
#
# The property under test: the linker owns exactly the paths in its manifest.
# It must place each one at its own store path, leave an already-correct link
# untouched so running sessions see no churn, and prune only links it used to
# own. Everything else in the same directory is somebody else's — a user's own
# symlink, or home-manager's aggregate, which still delivers siblings such as
# INDEX.md and GROUPS.json into the very same directory and cleans them up
# itself. Pruning those was a real defect: they survived the first deployment
# only because the activation entry happens to run before linkGeneration
# recreates them.
#
# STABLE_LINKS_STORE_PREFIX stands the fixture store in a tmpdir, matching the
# HM_FILES_STORE_GLOB convention in the cleanup scripts. Without it the prune
# branch is unreachable here and the test would pass without exercising the
# only destructive path in the script.

set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

store="$root/store"
home="$root/home"
skills="$home/.agents/skills"
mkdir -p "$store/skill-a" "$store/skill-b" "$store/aaaa-home-manager-files/.agents/skills" "$root/elsewhere" "$skills"
echo a >"$store/skill-a/SKILL.md"
echo b >"$store/skill-b/SKILL.md"
echo idx >"$store/aaaa-home-manager-files/.agents/skills/INDEX.md"

# Pre-existing state, one entry per behaviour under test.
mkdir -p "$skills/replaced-real-dir"
echo stale >"$skills/replaced-real-dir/leftover.txt" # a real dir in the way
ln -s "$store/skill-b" "$skills/already-correct"     # already at the right target
ln -s "$store/gone-away" "$skills/no-longer-managed" # ours once, dropped from the manifest
ln -s "$store/aaaa-home-manager-files/.agents/skills/INDEX.md" "$skills/INDEX.md"
ln -s "$root/elsewhere" "$skills/user-owned" # points outside the store

printf '.agents/skills/replaced-real-dir\t%s\n' "$store/skill-a" >"$root/manifest"
printf '.agents/skills/already-correct\t%s\n' "$store/skill-b" >>"$root/manifest"

log="$root/log"
STABLE_LINKS_STORE_PREFIX="$store/" bash "$SCRIPT" "$root/manifest" "$home" 2>"$log"

fail() {
  echo "FAIL: $1" >&2
  echo "--- linker output ---" >&2
  cat "$log" >&2
  echo "--- directory ---" >&2
  ls -la "$skills" >&2
  exit 1
}
expect_link() {
  [ -L "$1" ] || fail "$1 is not a symlink"
  [ "$(readlink "$1")" = "$2" ] || fail "$1 -> $(readlink "$1"), expected $2"
}

# A real directory in the way is replaced by the link, not backed up beside it.
expect_link "$skills/replaced-real-dir" "$store/skill-a"
if [ -e "$skills/replaced-real-dir/leftover.txt" ]; then
  fail "the replaced directory's contents survived"
fi

# An already-correct link is left alone: no churn for a running session.
expect_link "$skills/already-correct" "$store/skill-b"
grep -q 'unchanged=1' "$log" || fail "expected exactly one unchanged entry"

# A link we used to own and no longer do is pruned, and the removal is logged.
if [ -e "$skills/no-longer-managed" ] || [ -L "$skills/no-longer-managed" ]; then
  fail "a dropped manifest entry was not pruned"
fi
grep -q "pruned $skills/no-longer-managed" "$log" || fail "the prune was not logged"
grep -q 'pruned=1' "$log" || fail "the prune count did not survive the loop"

# home-manager's aggregate still delivers siblings into this directory. They are
# home-manager's to remove, never ours.
expect_link "$skills/INDEX.md" "$store/aaaa-home-manager-files/.agents/skills/INDEX.md"

# A symlink pointing outside the store belongs to whoever put it there.
expect_link "$skills/user-owned" "$root/elsewhere"

# Idempotence: a second run must change nothing and prune nothing.
log2="$root/log2"
STABLE_LINKS_STORE_PREFIX="$store/" bash "$SCRIPT" "$root/manifest" "$home" 2>"$log2"
grep -q 'linked=0 unchanged=2 pruned=0' "$log2" || {
  echo "FAIL: second run was not a no-op" >&2
  cat "$log2" >&2
  exit 1
}

echo ok >"$out"
