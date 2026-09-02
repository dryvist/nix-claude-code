#!/usr/bin/env bash
# Claude Code Hook: Keychain secret-read guard
#
# Denies a `security find-generic-password` / `security
# find-internet-password` Bash invocation that would PRINT the secret
# (`-w` dumps the password; `-g` dumps it plus attributes to stderr). A
# lookup that only inspects metadata (no -w/-g) still allows through — the
# guard exists because printing a secret writes it into the transcript, not
# because the lookup itself is sensitive.
#
# Hook Type: preToolUse
# Input: PreToolUse JSON on stdin (`tool_name`, `tool_input.command`).
# Output: a `permissionDecision: deny` decision, or nothing (allow).
#
# Fail-open by design, matching private-workspace-agent-guard.sh: missing or
# unparsable input allows the command rather than blocking unrelated work.

set -euo pipefail

input=$(cat)
[ "$(jq -r '.tool_name // empty' <<<"$input")" = "Bash" ] || exit 0

command=$(jq -r '.tool_input.command // empty' <<<"$input")
[ -n "$command" ] || exit 0

case "$command" in
*security\ find-generic-password* | *security\ find-internet-password*)
  case "$command" in
  *' -w'* | *' -g'*) ;;
  *)
    exit 0
    ;;
  esac
  ;;
*)
  exit 0
  ;;
esac

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: (
      "Blocked: `security find-generic-password`/`find-internet-password -w`/`-g` prints "
      + "the secret value into the transcript. Use `openbao-run` (or the equivalent "
      + "ephemeral-credential helper) instead of reading a keychain secret directly."
    )
  }
}'
