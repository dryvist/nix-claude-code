# Claude Code MCP Server Wiring
#
# Typed option lives in `./options-events.nix`. This module adds the
# assertions that catch malformed entries at evaluation time. The actual
# settings.json materialization happens in `./settings.nix` (which knows
# how to format stdio vs sse/http servers and respect `disabled`).
{ config, lib, ... }:
let
  cfg = config.programs.claude;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (v: v.type != "stdio" || v.command != null) (
          builtins.attrValues cfg.mcpServers
        );
        message = ''
          MCP servers with type "stdio" must have a command set.
          Check programs.claude.mcpServers for entries with type = "stdio" and command = null.
        '';
      }
      {
        assertion = lib.all (v: v.type == "stdio" || v.url != null) (builtins.attrValues cfg.mcpServers);
        message = ''
          MCP servers with type "sse" or "http" must have a url set.
          Check programs.claude.mcpServers for entries with type = "sse"/"http" and url = null.
        '';
      }
    ];
  };
}
