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
#
# jq must be on PATH (callers ensure this via PATH export or writeShellApplication).

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: merge-json-settings <nix-settings-path> <target-path>" >&2
  exit 1
fi

NIX_SETTINGS="$1"
TARGET="$2"

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
  # advisorModel strips for the same reason but by a different mechanism:
  # it's Nix-authoritative but OMITTED (not emptied) when disabled, so a
  # `del()` gap here doesn't just fossilize a stale value — a consumer
  # turning it off (settings.advisorModel = null) leaves the runtime file
  # holding whatever the *previous* Nix generation wrote, forever, since
  # the key is invisible to jq's `*` merge once Nix stops declaring it.
  #
  # `.env` strips by the same omission mechanism, one level down: Nix
  # rebuilds the whole env map every activation, so a variable DROPPED from
  # the Nix config simply stops appearing in the generated file. jq's `*`
  # then has nothing to overwrite it with, and the runtime file keeps
  # serving the removed variable to every session forever. Observed with a
  # model-tier override that stayed live for months after its declaration
  # was deleted, pointing sessions at a tier that no longer suited them.
  # Stripping is safe because Nix always emits `env` — the module merges
  # its own upstream defaults underneath, so the key is never absent.
  #
  # `.hooks` strips too, but conditionally: unlike `.env`, Nix only emits
  # `.hooks` when at least one typed hook or `settings.hooks` override is
  # configured (`hooksAttrs != {}` in modules/settings.nix) - so stripping
  # it unconditionally could wipe a hook a user added at runtime via
  # `/hooks` on a generation where Nix declares none. Stripping only when
  # this activation's Nix output actually has the key keeps the invariant
  # that a key Nix stops declaring vanishes, without touching the case Nix
  # never owned. Precedent: ClaudeBar (a since-removed macOS menu-bar app,
  # nix-darwin#1617) self-registered 6 hook events directly into this file;
  # removing the app never unregistered them, and they fired a doomed curl
  # at a dead port on every SessionEnd/Stop/Subagent*/TaskCompleted/
  # UserPromptSubmit for 7+ weeks with no visible error (backgrounded,
  # output discarded, wrapper always exits 0).
  #
  # The del() is a no-op on files without those keys (safe for Claude
  # settings.json).
  STRIP_FILTER='del(.mcpServers, .extraKnownMarketplaces, .enabledPlugins, .permissions.allow, .permissions.ask, .permissions.deny, .advisorModel, .env'
  if jq -e 'has("hooks")' "$NIX_SETTINGS" >/dev/null 2>&1; then
    STRIP_FILTER="${STRIP_FILTER}, .hooks"
  fi
  STRIP_FILTER="${STRIP_FILTER})"
  if ! STRIPPED=$(jq "$STRIP_FILTER" "$TARGET" 2>/dev/null); then
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
