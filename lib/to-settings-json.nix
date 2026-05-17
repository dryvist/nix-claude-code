{ lib }:
{
  permissions ? null,
  hooks ? null,
  statusLine ? null,
  enabledPlugins ? null,
  extraSettings ? { },
}:
# Build the contents of `~/.claude/settings.json` from structured inputs.
# Final shape follows https://json.schemastore.org/claude-code-settings.json.
#
# `permissions` is the attrset produced by `lib.mkDefaultPermissions`
# (six flat-keyed lists: allow, allowMcp, ask, deny, denyPatterns,
# webfetchDomains). This function applies Claude's permission DSL:
#
#   - shell commands     → `Bash(<cmd> *)` (the trailing ` *` is Claude's
#                          wildcard-with-word-boundary syntax)
#   - WebFetch domains   → `WebFetch(domain:<host>)`
#   - Read-deny patterns → `Read(<glob>)`
#   - MCP patterns       → pass-through (already in `mcp__<server>__*` form)
#
# Ordering inside each list matches the historical nix-ai output so the
# generated settings.json diffs cleanly during the migration:
# tool-specific entries first, then MCP, then shell commands.
let
  fmtBash = cmd: "Bash(${cmd} *)";
  fmtWebFetch = domain: "WebFetch(domain:${domain})";
  fmtReadPattern = pattern: "Read(${pattern})";

  formatAllow =
    p:
    map fmtWebFetch (p.webfetchDomains or [ ]) ++ (p.allowMcp or [ ]) ++ map fmtBash (p.allow or [ ]);

  formatAsk = p: map fmtBash (p.ask or [ ]);

  formatDeny = p: map fmtBash (p.deny or [ ]) ++ map fmtReadPattern (p.denyPatterns or [ ]);

  settingsPermissions =
    if permissions == null then
      null
    else
      {
        allow = formatAllow permissions;
        ask = formatAsk permissions;
        deny = formatDeny permissions;
      };

  # Drop keys with `null` values so the final JSON only carries inputs the
  # caller actually supplied. Anthropic's schema treats omitted keys and
  # explicit nulls differently in some places — omitting is safer.
  defined = lib.filterAttrs (_: v: v != null) {
    permissions = settingsPermissions;
    inherit hooks statusLine enabledPlugins;
  };
in
defined
// {
  "$schema" = "https://json.schemastore.org/claude-code-settings.json";
}
// extraSettings
