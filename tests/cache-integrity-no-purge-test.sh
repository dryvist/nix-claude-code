#!/usr/bin/env bash
# Regression test for modules/scripts/verify-cache-integrity.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   SCRIPT  store path of the script under test
#   out     file to write the success marker to
#
# The property under test: detecting a moved marketplace must NOT delete the
# plugin cache. The script used to `rm -rf` the whole marketplace cache dir on
# a store-path change, at marketplace granularity, while live sessions pin
# plugin/version granularity. On 2026-09-05 that deleted directories out from
# under every running session: hooks re-stat ${CLAUDE_PLUGIN_ROOT} on each
# invocation and all of them failed with "Plugin directory does not exist".
#
# Reclaiming superseded versions is Claude Code's job — it refcounts each one
# with .in_use/<pid> and keeps it for a grace period. This script only detects
# and marks.

set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

config="$root/config"
cache="$config/plugins/cache"
marketplaces="$config/plugins/marketplaces"
mkdir -p "$cache" "$marketplaces"

# A marketplace symlink pointing at an "old" store path, and cached plugins
# installed from it — including a version dir held by a live session.
#
# The targets are deliberately dangling: the script only ever hashes the
# readlink STRING and ignores any symlink whose target is not under /nix/store,
# so the fixture must look like a store path but need not exist.
old_target="/nix/store/0000000000000000000000000000000-old-marketplace"
new_target="/nix/store/1111111111111111111111111111111-new-marketplace"
ln -s "$old_target" "$marketplaces/example-mkt"

held="$cache/example-mkt/some-plugin/1.0.0"
superseded="$cache/example-mkt/other-plugin/0.9.0"
mkdir -p "$held/.in_use" "$superseded"
echo '{"pid":4242}' >"$held/.in_use/4242"
echo hook >"$held/hook.sh"
echo old >"$superseded/marker"

run() { bash "${SCRIPT:?SCRIPT not set}" "$config" >>"$log" 2>&1 || fail "script exited non-zero"; }
log="$root/log"
: >"$log"

fail() {
  echo "FAIL: $1" >&2
  cat "$log" >&2
  exit 1
}

# First run: no recorded hashes yet, so the marketplace reads as changed.
run

[ -d "$held" ] || fail "cache dir held by a live session was deleted (the purge bug)"
[ -f "$held/hook.sh" ] || fail "hook script inside a live cache dir was deleted"
[ -f "$held/.in_use/4242" ] || fail "live-session refcount marker was deleted"
[ -d "$superseded" ] || fail "superseded version dir was deleted; reclamation is Claude Code's job"
[ -f "$cache/.nix-refresh-needed" ] || fail "refresh marker not written"
grep -q "marketplace=example-mkt" "$cache/.nix-refresh-needed" || fail "marker missing the marketplace"
[ -f "$cache/.nix-store-hashes" ] || fail "hash file not written"

# Repoint the symlink: the store path moved, which is exactly the condition
# that used to trigger the purge. Nothing may be deleted.
rm "$marketplaces/example-mkt"
ln -s "$new_target" "$marketplaces/example-mkt"
run

[ -d "$held" ] || fail "cache dir deleted after a store-path change (the purge bug)"
[ -d "$superseded" ] || fail "superseded dir deleted after a store-path change"
grep -q "marketplace=example-mkt" "$cache/.nix-refresh-needed" || fail "marker not refreshed on move"

# The hash file must record the NEW path, so an unchanged third run is quiet.
: >"$cache/.nix-refresh-needed"
run
[ -s "$cache/.nix-refresh-needed" ] && fail "marker rewritten when nothing moved"

# Idempotence: still no deletions.
[ -d "$held" ] || fail "third run deleted a live cache dir"
[ -d "$superseded" ] || fail "third run deleted a superseded cache dir"

echo ok >"${out:-$root/out}"
echo "cache-integrity no-purge: all cases pass"
