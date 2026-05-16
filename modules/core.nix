{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude;
in
{
  options.programs.claude = {
    enable = lib.mkEnableOption "Claude Code as a declarative home-manager module";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.claude-code or null;
      defaultText = lib.literalExpression "pkgs.claude-code";
      description = ''
        The Claude Code package. Set to `null` to skip installing the binary
        (useful if you manage Claude Code via Homebrew or another channel).
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Free-form contents of `~/.claude/settings.json`. Module-generated values
        (permissions, plugins, mcpServers) are merged on top.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (cfg.package != null) [ cfg.package ];
  };
}
