#!/usr/bin/env bash
# Regression test for merge-json-settings.sh's advisorModel handling.
#
# A previous activation can leave `advisorModel` sitting in the runtime
# settings.json (Nix wrote it while a consumer had it set). If a consumer
# then disables it (settings.advisorModel = null, so Nix's rendered output
# omits the key entirely), the merge must still clear the stale value —
# jq's `*` merge never deletes a key the right-hand side simply doesn't
# mention. Guards the exact failure this script's `del()` list exists to
# prevent.
#
# Arguments:
#   $1 - Path to merge-json-settings.sh

set -euo pipefail

MERGE_SCRIPT="$1"

existing=$(mktemp)
nix_settings=$(mktemp)
target=$(mktemp)

echo '{"advisorModel":"fable","someRuntimeKey":"keepme"}' >"$existing"
cp "$existing" "$target"
echo '{"cleanupPeriodDays":180}' >"$nix_settings"

bash "$MERGE_SCRIPT" "$nix_settings" "$target"

jq -e 'has("advisorModel") | not' "$target" >/dev/null || {
  echo "advisorModel survived the merge despite Nix omitting it:" >&2
  cat "$target" >&2
  exit 1
}
jq -e '.someRuntimeKey == "keepme"' "$target" >/dev/null || {
  echo "unrelated runtime-only key was not preserved:" >&2
  cat "$target" >&2
  exit 1
}
echo ok
