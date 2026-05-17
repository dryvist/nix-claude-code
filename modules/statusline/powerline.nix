{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude.statusline;
  active = config.programs.claude.enable && cfg.enable && cfg.theme == "powerline";

  configFile = ./claude-powerline.json;

  script = pkgs.writeShellScript "claude-powerline" ''
    # @owloops/claude-powerline statusline (semver-pinned for stability)
    exec ${pkgs.bun}/bin/bunx @owloops/claude-powerline@'^1' --config=${configFile} "$@"
  '';
in
{
  config = lib.mkIf active {
    programs.claude.settings.statusLine = {
      type = "command";
      command = "${script}";
      inherit (cfg) padding;
    };
  };
}
