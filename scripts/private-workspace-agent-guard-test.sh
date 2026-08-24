#!/usr/bin/env bash
# Regression test for modules/hooks/private-workspace-agent-guard.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   GUARD  store path of the guard script under test
#   out    file to write the success marker to
#
# A stub `curl` on PATH stands in for the router's /model/info, so the check
# stays hermetic — a sandboxed build has no network.

set -euo pipefail

export XDG_CACHE_HOME="$(mktemp -d)"
export GIT_HOME_PRIVATE=/tmp/workspace/private
export ANTHROPIC_BASE_URL=http://127.0.0.1:4100

fakebin="$(mktemp -d)"
export PATH="$fakebin:$PATH"

# Swap the stub curl's canned body and drop the 60s cache, so every case
# really re-reads /model/info.
stub_body() {
  printf '%s' "$1" >"$fakebin/model-info.json"
  printf '#!/bin/sh\ncat %s/model-info.json\n' "$fakebin" >"$fakebin/curl"
  chmod +x "$fakebin/curl"
  rm -f "$XDG_CACHE_HOME/claude-subagent-role.json"
}

run() {
  printf '{"tool_name":"Agent","cwd":"%s"}' "$1" | bash "$GUARD"
}

external='{"data":[{"model_name":"subagent","litellm_params":{"model":"openrouter/vendor/model"}}]}'
loopback='{"data":[{"model_name":"subagent","litellm_params":{"model":"openai/local","api_base":"http://127.0.0.1:4100/v1"}}]}'

# External deployment + private cwd -> deny.
stub_body "$external"
decision=$(run /tmp/workspace/private/owner/repo |
  jq -r '.hookSpecificOutput.permissionDecision')
[ "$decision" = "deny" ] || {
  echo "expected deny for an external subagent role, got: $decision" >&2
  exit 1
}

# Same deployment, cwd outside the private workspace -> allow.
got=$(run /tmp/workspace/public/family/repo)
[ -z "$got" ] || {
  echo "expected allow outside the private workspace, got: $got" >&2
  exit 1
}

# Loopback-local deployment + private cwd -> allow.
stub_body "$loopback"
got=$(run /tmp/workspace/private/owner/repo)
[ -z "$got" ] || {
  echo "expected allow for a loopback-local subagent role, got: $got" >&2
  exit 1
}

# Unreachable endpoint -> fail open, with one stderr line.
printf '#!/bin/sh\nexit 22\n' >"$fakebin/curl"
chmod +x "$fakebin/curl"
rm -f "$XDG_CACHE_HOME/claude-subagent-role.json"
got=$(run /tmp/workspace/private/owner/repo 2>stderr.log)
[ -z "$got" ] || {
  echo "expected fail-open when /model/info is unreachable, got: $got" >&2
  exit 1
}
grep -q "unreachable" stderr.log || {
  echo "expected a stderr line naming the unreachable endpoint, got:" >&2
  cat stderr.log >&2
  exit 1
}

echo ok >"$out"
