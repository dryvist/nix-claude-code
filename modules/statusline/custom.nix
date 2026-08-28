{
  config,
  lib,
  ...
}:
let
  claudeCfg = config.programs.claude;
  cfg = claudeCfg.statusline;
  active = claudeCfg.enable && cfg.enable && cfg.theme == "custom" && cfg.script != null;
in
{
  config = lib.mkIf active {
    # Render the user-supplied script body to a managed file and reference
    # it from settings.json. The home-relative path keeps the file
    # readable by Claude Code without dragging in the Nix store path.
    home.file."${claudeCfg.configDir}/statusline-command.sh" = {
      text = cfg.script;
      executable = true;
    };

    programs.claude.settings.statusLine = {
      type = "command";
      command = "${claudeCfg.configDirAbs}/statusline-command.sh";
      inherit (cfg) padding;
    };
  };
}
