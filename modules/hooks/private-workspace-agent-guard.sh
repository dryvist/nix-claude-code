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
#   LLM_ROUTER_TOKEN_FILE  path to the upstream router bearer
#   OPENAI_API_KEY     bearer fallback when that path is unset or unreadable
#   ANTHROPIC_BASE_URL local proxy base URL — probed only as a fallback
#   LITELLM_LOCAL_KEY  local proxy key, sent as `x-litellm-api-key`
#   XDG_CACHE_HOME     cache root for the 60s /model/info cache
#   CLAUDE_SUBAGENT_INTERNAL_DOMAINS
#                      space-separated domains whose hosts are self-hosted, so
#                      a role target based there counts as internal. Declared,
#                      never inferred: a domain guessed from another URL can
#                      land on a public suffix and allowlist every host under
#                      it. Unset ⇒ only loopback counts as internal.

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
#
# The bearer comes from LLM_ROUTER_TOKEN_FILE, never from OPENAI_API_KEY:
# on a workstation that variable is overridden to the local proxy's key.
if [ -n "${LLM_ROUTER_URL:-}" ]; then
  base_url="$LLM_ROUTER_URL"
  if [ -r "${LLM_ROUTER_TOKEN_FILE:-}" ]; then
    auth_header="Authorization: Bearer $(cat "$LLM_ROUTER_TOKEN_FILE")"
  else
    auth_header="Authorization: Bearer ${OPENAI_API_KEY:-}"
  fi
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

# Local means an openai/ or anthropic/ deployment whose base URL stays inside
# the operator's own estate: loopback, or a host in one of the domains they
# declared as self-hosted. Self-hosted models are served from other machines,
# not from the machine running this hook, so loopback alone would leave the
# allow path unreachable — but the domain is declared rather than derived from
# another URL, because a derived one can land on a public suffix and allowlist
# every host beneath it. Everything else — an openrouter/ model, any other
# provider prefix, a base URL on an undeclared domain, or no base URL at all —
# counts as external.
model=$(jq -r '.model // ""' <<<"$params")
api_base=$(jq -r '.api_base // ""' <<<"$params")

api_host=${api_base#*://}
api_host=${api_host%%/*}
api_host=${api_host%%:*}

is_local=false
case "$model" in
openai/* | anthropic/*)
  case "$api_host" in
  127.0.0.1 | localhost | "[::1]") is_local=true ;;
  ?*)
    for internal_domain in ${CLAUDE_SUBAGENT_INTERNAL_DOMAINS:-}; do
      case "$api_host" in
      "$internal_domain" | *".$internal_domain")
        is_local=true
        break
        ;;
      esac
    done
    ;;
  esac
  ;;
esac

[ "$is_local" = true ] && exit 0

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
