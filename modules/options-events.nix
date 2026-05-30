# Claude Code Module — Event hook + MCP server options
#
# Hooks fire on Claude Code lifecycle events (preToolUse, sessionStart, etc.)
# and run as scripts in ~/.claude/hooks/. MCP servers expose Model Context
# Protocol tools/resources to the running session.
{ lib, ... }:
let
  inherit (import ./options-types.nix { inherit lib; }) mcpServerModule hookType;
in
{
  options.programs.claude = {
    # Hooks - fully implemented in modules/hooks.nix (typed per-event hooks)
    # plus modules/settings.nix (free-form pass-through).
    hooks = {
      preToolUse = lib.mkOption {
        type = hookType;
        default = null;
      };
      postToolUse = lib.mkOption {
        type = hookType;
        default = null;
      };
      userPromptSubmit = lib.mkOption {
        type = hookType;
        default = null;
      };
      stop = lib.mkOption {
        type = hookType;
        default = null;
      };
      subagentStop = lib.mkOption {
        type = hookType;
        default = null;
      };
      sessionStart = lib.mkOption {
        type = hookType;
        default = null;
      };
      sessionEnd = lib.mkOption {
        type = hookType;
        default = null;
      };

      # High-level toggle: wires postToolUse to a vendored capture script.
      captureSessionOutput = lib.mkEnableOption ''
        session-output capture hook. When enabled, sets `postToolUse` to
        a vendored script that writes a compact summary of each tool
        invocation to `~/.cache/claude-last-output.txt` for statusline
        consumption.
      '';

      # High-level toggle: wires sessionStart to a marketplace-refresh helper.
      refreshMarketplaces = lib.mkEnableOption ''
        marketplace-refresh hook. When enabled, sets `sessionStart` to a
        vendored script that asks Claude Code to re-read marketplace
        manifests at session start (useful after a Nix rebuild).
      '';
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf mcpServerModule;
      default = { };
      description = ''
        MCP server definitions written to `~/.claude/settings.json` under
        `mcpServers`. Typed: stdio servers need `command`+`args`;
        sse/http servers need `url`.
      '';
    };
  };
}
