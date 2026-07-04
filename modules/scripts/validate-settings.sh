#!/usr/bin/env bash
# Validate ~/.claude/settings.json against its declared JSON Schema.
# Called by home-manager activation (see `validateClaudeSettings` in
# ../settings.nix) after the settings file has been merged.
#
# Arguments:
#   $1 - Path to settings.json
#   $2 - Schema URL (from `programs.claude.settings.schemaUrl`)
#
# Exit codes:
#   0 - Always. Validation failures are reported as warnings to stderr and
#       never block activation — the schema evolves faster than this repo,
#       and a network-dependent check must not be able to break `switch`.
#   1 - Only on argument/usage error.

set -euo pipefail

SETTINGS="${1:-}"
SCHEMA_URL="${2:-}"

if [ -z "$SETTINGS" ] || [ -z "$SCHEMA_URL" ]; then
  echo "Usage: $0 <settings-path> <schema-url>" >&2
  exit 1
fi

if [ ! -f "$SETTINGS" ]; then
  # Settings file doesn't exist yet - normal during first activation.
  exit 0
fi

# Ephemeral nix shell keeps this out of the persistent closure; warn but
# never fail activation on validation errors (including no network).
nix shell nixpkgs#check-jsonschema -c check-jsonschema --schemafile "$SCHEMA_URL" "$SETTINGS" || {
  echo "Warning: Claude Code settings.json failed schema validation against $SCHEMA_URL" >&2
}
