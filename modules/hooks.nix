{ config, lib, ... }:
{
  options.programs.claude.hooks = {
    captureSessionOutput = lib.mkEnableOption "session-output capture hook";
    refreshMarketplaces = lib.mkEnableOption "marketplace-refresh hook";

    extraHooks = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Free-form `hooks` attrset merged into Claude's `settings.json` per
        Anthropic's [hooks reference](https://code.claude.com/docs/en/hooks).
      '';
    };
  };

  config = lib.mkIf config.programs.claude.enable {
    # Stub: hook script generation lands in Checkpoint 1.
  };
}
