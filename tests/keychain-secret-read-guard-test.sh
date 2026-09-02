#!/usr/bin/env bash
# Regression test for modules/hooks/keychain-secret-read-guard.sh.
#
# Run as a Nix check (see flake/checks.nix), which supplies:
#   GUARD  store path of the guard script under test
#   out    file to write the success marker to

set -euo pipefail

run() {
  jq -nc --arg cmd "$1" '{tool_name:"Bash",tool_input:{command:$cmd}}' | bash "$GUARD"
}

# -w prints the password -> deny.
decision=$(run 'security find-generic-password -s BAO_ADDR -w' | jq -r '.hookSpecificOutput.permissionDecision')
[ "$decision" = "deny" ] || {
  echo "expected deny for a -w read, got: $decision" >&2
  exit 1
}

# -g also dumps the password (plus attributes) -> deny.
decision=$(run 'security find-generic-password -g -s BAO_ADDR' | jq -r '.hookSpecificOutput.permissionDecision')
[ "$decision" = "deny" ] || {
  echo "expected deny for a -g read, got: $decision" >&2
  exit 1
}

# find-internet-password is the same class of leak -> deny.
decision=$(run 'security find-internet-password -s example.com -w' | jq -r '.hookSpecificOutput.permissionDecision')
[ "$decision" = "deny" ] || {
  echo "expected deny for find-internet-password -w, got: $decision" >&2
  exit 1
}

# No -w/-g: existence/metadata-only lookup -> allow.
got=$(run 'security find-generic-password -s BAO_ADDR')
[ -z "$got" ] || {
  echo "expected allow for a metadata-only read, got: $got" >&2
  exit 1
}

# Unrelated Bash command -> allow.
got=$(run 'security list-keychains')
[ -z "$got" ] || {
  echo "expected allow for an unrelated security subcommand, got: $got" >&2
  exit 1
}

# Non-Bash tool -> allow (the guard only inspects Bash commands).
got=$(jq -nc '{tool_name:"Read",tool_input:{command:"security find-generic-password -w"}}' | bash "$GUARD")
[ -z "$got" ] || {
  echo "expected allow for a non-Bash tool_name, got: $got" >&2
  exit 1
}

echo ok >"$out"
