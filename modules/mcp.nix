{ config, lib, ... }:
{
  options.programs.claude.mcpServers = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    example = lib.literalExpression ''
      {
        my-server = {
          command = "''${pkgs.my-mcp-server}/bin/my-mcp-server";
          args = [ ];
          env = { };
        };
      }
    '';
    description = ''
      MCP server definitions written to `~/.claude/settings.json` under
      `mcpServers`. This module only surfaces the option; populate it from
      whichever MCP runtime you use (e.g. `nix-ai`'s `modules/mcp`).
    '';
  };

  config = lib.mkIf config.programs.claude.enable {
    # Stub: mcpServers are merged into settings.json in Checkpoint 1.
  };
}
