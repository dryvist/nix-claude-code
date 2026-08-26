#!/usr/bin/env bash
# Deep-merge Nix-generated JSON settings with existing runtime state.
#
# Preserves runtime-only keys while updating Nix-managed settings.
# Merge strategy: existing runtime file as base, Nix config overlaid on top.
# Nix-managed keys always win, but runtime-only keys are preserved.
#
# Arguments:
#   $1 - Path to Nix-generated settings JSON (in /nix/store)
#   $2 - Path to target settings file
#   $3 - (optional) Path to a JSON array of Nix-managed environment variable
#        names. When given, those names are stripped from `.env` in the
#        pre-existing file before the deep merge, so a key the Nix config no
#        longer emits is removed on activation instead of being fossilized
#        forever. Every other `.env` entry and all other top-level keys are
#        preserved. The deletion is a no-op when `.env` or a named key does
#        not exist, and an empty/managed-less array strips nothing.
#
# jq must be on PATH (callers ensure this via PATH export or writeShellApplication).

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: merge-json-settings <nix-settings-path> <target-path> [managed-env-keys-json-path]" >&2
  exit 1
fi

NIX_SETTINGS="$1"
TARGET="$2"
MANAGED_KEYS_FILE="${3:-}"

TARGET_NAME=$(basename "$TARGET")
TARGET_DIR=$(dirname "$TARGET")
mkdir -p "$TARGET_DIR"

if [[ -f $TARGET ]] && [[ ! -L $TARGET ]]; then
  # File exists and is a real file (not symlink) - merge
  # Strip Nix-authoritative sections from existing config before merge.
  # This prevents stale entries (e.g. removed MCP servers, a marketplace
  # whose source shape changed, or an unlisted plugin) from persisting.
  # Every stripped key is regenerated in full from Nix each activation, so a
  # deep merge would only fossilize stale sub-keys — and jq's `*` merges
  # arrays BY INDEX, so without stripping, a shrunken Nix list would keep
  # the old list's trailing entries alive.
  #
  # The permission rule lists are stripped for that exact reason: Nix now
  # emits them empty (the auto-mode classifier is the gate), and an empty
  # list merged by index would leave every previously-deployed entry — and
  # anything a user added at runtime through /permissions — alive forever.
  # Only the three rule lists go; `.permissions.additionalDirectories` and
  # any other runtime sub-key under `.permissions` are preserved.
  #
  # The del() is a no-op on files without those keys (safe for Claude
  # settings.json).
  # When a managed-env-keys manifest is supplied, its names are also cleared
  # from `.env` so a key the Nix config no longer emits is removed on the
  # next activation instead of fossilized forever. Deletion is a no-op on
  # files where the named key (or `.env` itself) is absent, and a
  # now-empty `.env` object is dropped. The two-argument path keeps the
  # original program byte-for-byte for backward compatibility.
  if [[ -n $MANAGED_KEYS_FILE ]]; then
    # shellcheck disable=SC2016 # $managed is a jq slurpfile var, not a shell ref
    STRIP_PROGRAM='
      del(.mcpServers, .extraKnownMarketplaces, .enabledPlugins,
          .permissions.allow, .permissions.ask, .permissions.deny)
      | delpaths([ $managed[0][] | ["env", .] ])
      | if ((.env? // {}) == {}) then del(.env) else . end
    '
    STRIP_ARGS=(--slurpfile managed "$MANAGED_KEYS_FILE")
  else
    STRIP_PROGRAM='del(.mcpServers, .extraKnownMarketplaces, .enabledPlugins, .permissions.allow, .permissions.ask, .permissions.deny)'
    STRIP_ARGS=()
  fi
  if ! STRIPPED=$(jq "${STRIP_ARGS[@]}" "$STRIP_PROGRAM" "$TARGET" 2>/dev/null); then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to strip Nix-managed keys from existing ${TARGET_NAME}, using existing file contents as-is" >&2
    if ! STRIPPED=$(cat "$TARGET"); then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to read existing ${TARGET_NAME}, using Nix config" >&2
      cp "$NIX_SETTINGS" "$TARGET"
      chmod 600 "$TARGET"
      exit 0
    fi
  fi
  # jq -s '.[0] * .[1]' merges deeply: [0]=existing runtime (stripped), [1]=Nix config
  # Nix config wins on conflicts, runtime-only keys are preserved
  MERGED=$(jq -s '.[0] * .[1]' - "$NIX_SETTINGS" <<<"$STRIPPED") || {
    # If merge fails (e.g., invalid JSON in target), just use Nix settings
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Failed to merge existing ${TARGET_NAME}, using Nix config" >&2
    cp "$NIX_SETTINGS" "$TARGET"
    chmod 600 "$TARGET"
    exit 0
  }
  printf '%s\n' "$MERGED" >"${TARGET}.tmp"
  mv "${TARGET}.tmp" "$TARGET"
  chmod 600 "$TARGET"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Merged ${TARGET_NAME} (preserved runtime state)"
elif [[ -L $TARGET ]]; then
  # It's a symlink (old Nix-managed) - remove and create real file
  rm "$TARGET"
  cp "$NIX_SETTINGS" "$TARGET"
  chmod 600 "$TARGET"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Replaced Nix symlink with writable ${TARGET_NAME}"
else
  # No existing file - just copy
  cp "$NIX_SETTINGS" "$TARGET"
  chmod 600 "$TARGET"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Created initial ${TARGET_NAME}"
fi
