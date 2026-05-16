{ config, lib, ... }:
let
  cfg = config.programs.claude;
in
{
  options.programs.claude = {
    enabledPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      example = lib.literalExpression ''
        {
          "agent-orchestration@claude-code-workflows" = true;
          "github@claude-plugins-official" = true;
        }
      '';
      description = ''
        Plugins to enable, keyed by `"plugin-name@marketplace-name"`. The marketplace
        catalog is parsed from each marketplace input's `.claude-plugin/marketplace.json`
        per Anthropic's [official spec](https://code.claude.com/docs/en/plugins).
      '';
    };

    marketplaces = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = ''
        Additional marketplace entries to register beyond the canonical default set.
        Each entry maps to a `source` block in Claude's `known_marketplaces.json`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Stub: marketplace discovery + plugin resolution lands in Checkpoint 1.
  };
}
