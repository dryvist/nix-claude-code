#!/usr/bin/env bash
# Claude Code Hook: Private-workspace subagent guard
#
# Blocks Agent-tool spawns when BOTH hold:
#   a) the session cwd is inside $GIT_HOME_PRIVATE, and
#   b) the router role `subagent` currently resolves to an external provider.
#
# Hook Type: preToolUse
# Input: PreToolUse JSON on stdin (`tool_name`, `cwd`).
# Output: a `permissionDecision: deny` decision, or nothing (allow).
#
# `updatedInput.model` is ignored for the Agent tool, so blocking is the only
# working control here.
#
# Fail-open by design: any missing input, unset variable, or unreachable
# endpoint allows the spawn and logs one line to stderr. A guard that fails
# closed on an unrelated outage would block all delegation.
#
# Environment:
#   GIT_HOME_PRIVATE   root of the private workspace (unset ⇒ allow)
#   LLM_ROUTER_URL     upstream router base URL — probed first
#   OPENAI_API_KEY     upstream router bearer
#   ANTHROPIC_BASE_URL local proxy base URL — probed only as a fallback
#   LITELLM_LOCAL_KEY  local proxy key, sent as `x-litellm-api-key`
#   XDG_CACHE_HOME     cache root for the 60s /model/info cache

set -euo pipefail

CACHE_TTL=60
CACHE_FILE="${XDG_CACHE_HOME:-${TMPDIR:-/tmp}}/claude-subagent-role.json"

allow() {
  [ "$#" -eq 0 ] || echo "private-workspace-agent-guard: $1 — allowing" >&2
  exit 0
}

input=$(cat)
[ "$(jq -r '.tool_name // empty' <<<"$input")" = "Agent" ] || exit 0

private_root="${GIT_HOME_PRIVATE:-}"
[ -n "$private_root" ] || allow "GIT_HOME_PRIVATE unset"

cwd=$(jq -r '.cwd // empty' <<<"$input")
case "$cwd" in
"$private_root" | "$private_root"/*) ;;
*) exit 0 ;;
esac

# Probe the upstream router, where role aliases actually resolve to models.
# The local proxy forwards roles through a wildcard deployment, so asking it
# would only ever report the wildcard — never the provider behind the role.
if [ -n "${LLM_ROUTER_URL:-}" ]; then
  base_url="$LLM_ROUTER_URL"
  auth_header="Authorization: Bearer ${OPENAI_API_KEY:-}"
else
  base_url="${ANTHROPIC_BASE_URL:-}"
  auth_header="x-litellm-api-key: ${LITELLM_LOCAL_KEY:-}"
fi
[ -n "$base_url" ] || allow "LLM_ROUTER_URL and ANTHROPIC_BASE_URL both unset"

# Cache line 1 is the fetch timestamp; the rest is the /model/info body.
# Only successful fetches are cached, and the write is atomic so a
# concurrent hook never reads a torn file.
now=$(date +%s)
info=""
if [ -r "$CACHE_FILE" ]; then
  cached_at=$(head -n 1 "$CACHE_FILE")
  if [ "$((now - ${cached_at:-0}))" -lt "$CACHE_TTL" ]; then
    info=$(tail -n +2 "$CACHE_FILE")
  fi
fi

if [ -z "$info" ]; then
  info=$(curl -sf --connect-timeout 3 "${base_url%/}/model/info" \
    -H "$auth_header") || allow "/model/info unreachable"
  tmp=$(mktemp "${CACHE_FILE}.XXXXXX")
  printf '%s\n%s\n' "$now" "$info" >"$tmp" && mv -f "$tmp" "$CACHE_FILE"
fi

# First deployment named `subagent` is what the role resolves to today.
params=$(jq -c 'first(.data[]? | select(.model_name == "subagent") | .litellm_params) // empty' <<<"$info") ||
  allow "/model/info returned no parsable body"
[ -n "$params" ] && [ "$params" != "null" ] || allow "no deployment named 'subagent'"

# Local means an openai/ or anthropic/ deployment pointed at a loopback base.
# Everything else — an openrouter/ model, any other provider prefix, or a
# non-loopback base — counts as external.
is_local=$(jq -r '
  (.model // "") as $m
  | (.api_base // "") as $b
  | (($m | test("^(openai|anthropic)/")) and ($b | test("^https?://(127\\.0\\.0\\.1|localhost|\\[::1\\])(:|/|$)")))
' <<<"$params")

[ "$is_local" = "true" ] && exit 0

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: (
      "Blocked: cwd is in the private workspace and role `subagent` resolves to an external provider. "
      + "Switch role `subagent` to a local model in the router admin UI to allow this."
    )
  }
}'
