#!/usr/bin/env bash
# Regression test for merge-json-settings.sh managed-env-key stripping.
# Proves three behaviors: the enabling transition (the Nix overlay wins over
# a stale value), the disabling transition (every managed name is scrubbed
# when Nix stops emitting it, while unrelated runtime keys survive), and
# backward compatibility (a two-argument invocation is unchanged, so the
# managed program is gated on the optional third argument).
#
# Usage: managed-env-strip.sh /path/to/merge-json-settings.sh
#   jq must be on PATH.
set -euo pipefail

script="${1:?usage: managed-env-strip.sh <merger-script-path>}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

managed='["ANTHROPIC_BASE_URL","ANTHROPIC_CUSTOM_HEADERS","CLAUDE_CODE_SUBAGENT_MODEL","ANTHROPIC_DEFAULT_HAIKU_MODEL","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"]'

# ENABLED: a stale base URL must lose to the loopback overlay, and the
# unrelated runtime key must survive the strip-and-merge.
mkdir -p "$work/enabled"
cat >"$work/enabled/target.json" <<'EOF'
{"env":{"ANTHROPIC_BASE_URL":"http://stale.example","USER_RUNTIME":"keep"},"permissions":{"allow":[]}}
EOF
cat >"$work/enabled/nix.json" <<'EOF'
{"env":{"ANTHROPIC_BASE_URL":"http://127.0.0.1:4100","CLAUDE_CODE_SUBAGENT_MODEL":"subagent"}}
EOF
printf '%s\n' "$managed" >"$work/enabled/managed.json"
bash "$script" "$work/enabled/nix.json" "$work/enabled/target.json" "$work/enabled/managed.json"
[[ "$(jq -r '.env.ANTHROPIC_BASE_URL' "$work/enabled/target.json")" == "http://127.0.0.1:4100" ]] || {
  echo "ENABLED: base URL not overridden" >&2
  exit 1
}
[[ "$(jq -r '.env.CLAUDE_CODE_SUBAGENT_MODEL' "$work/enabled/target.json")" == "subagent" ]] || {
  echo "ENABLED: subagent marker missing" >&2
  exit 1
}
[[ "$(jq -r '.env.USER_RUNTIME' "$work/enabled/target.json")" == "keep" ]] || {
  echo "ENABLED: runtime key dropped" >&2
  exit 1
}

# DISABLED: a writable file carrying every managed name plus a runtime key
# must lose all five managed names under an env-less overlay while the
# unrelated runtime key survives.
mkdir -p "$work/disabled"
cat >"$work/disabled/target.json" <<'EOF'
{"env":{"ANTHROPIC_BASE_URL":"a","ANTHROPIC_CUSTOM_HEADERS":"b","CLAUDE_CODE_SUBAGENT_MODEL":"c","ANTHROPIC_DEFAULT_HAIKU_MODEL":"d","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY":"e","USER_RUNTIME":"keep"}}
EOF
cat >"$work/disabled/nix.json" <<'EOF'
{"env":{}}
EOF
bash "$script" "$work/disabled/nix.json" "$work/disabled/target.json" "$work/enabled/managed.json"
for k in ANTHROPIC_BASE_URL ANTHROPIC_CUSTOM_HEADERS CLAUDE_CODE_SUBAGENT_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY; do
  [[ "$(jq -r --arg k "$k" '((.env?) // {})[$k] | type' "$work/disabled/target.json")" == "null" ]] || {
    echo "DISABLED: managed key $k not scrubbed" >&2
    exit 1
  }
done
[[ "$(jq -r '.env.USER_RUNTIME' "$work/disabled/target.json")" == "keep" ]] || {
  echo "DISABLED: runtime key dropped" >&2
  exit 1
}

# BACKCOMPAT: without the optional third argument the stale base URL must
# survive (managed scrubbing is gated on that argument's presence).
mkdir -p "$work/compat"
cat >"$work/compat/target.json" <<'EOF'
{"env":{"ANTHROPIC_BASE_URL":"http://stale.example","USER_RUNTIME":"keep"}}
EOF
bash "$script" "$work/disabled/nix.json" "$work/compat/target.json"
[[ "$(jq -r '.env.ANTHROPIC_BASE_URL' "$work/compat/target.json")" == "http://stale.example" ]] || {
  echo "BACKCOMPAT: behavior changed without third arg" >&2
  exit 1
}

echo "managed-env-strip: ENABLED+DISABLED+BACKCOMPAT ok"
