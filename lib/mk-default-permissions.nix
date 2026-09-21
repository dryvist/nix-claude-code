{ lib }:
{
  tool ? "claude",
}:
let
  permissions = import ./permissions.nix { inherit lib; };
  forTool = permissions.toolSpecific.${tool} or { };
in
{
  # Shell commands auto-approved for this tool. Per-tool overrides append
  # to the shared base list — they never subtract.
  allow = permissions.allow.commands ++ (forTool.allow or [ ]);

  # MCP-server tool-name patterns auto-approved for this tool. No
  # per-tool overrides today; callers extend by importing
  # `permissions.allow.mcp` directly.
  allowMcp = permissions.allow.mcp;

  # Shell commands that prompt the user before execution.
  ask = permissions.ask.commands ++ (forTool.ask or [ ]);

  # Shell commands hard-denied.
  deny = permissions.deny.commands ++ (forTool.deny or [ ]);

  # Shell commands hard-denied as an EXACT match only — never a prefix.
  # Reserved for a bare invocation that is dangerous on its own but whose
  # subcommands are deliberately kept in `allow` (a prefix deny here would
  # also swallow those, since deny wins over allow regardless of
  # specificity). See `data/permissions/deny.nix`'s `commandsExact`.
  denyExact = permissions.deny.commandsExact or [ ] ++ (forTool.denyExact or [ ]);

  # File-path glob patterns hard-denied for Read/Edit/Write.
  denyPatterns = permissions.deny.patterns;

  # WebFetch-allowed domains.
  webfetchDomains = permissions.domains.webfetch;
}
