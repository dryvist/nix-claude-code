{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.claude.statusline;
  active = config.programs.claude.enable && cfg.enable && cfg.theme == "custom" && cfg.script != null;
in
{
  config = lib.mkIf active {
    # Render the user-supplied script body to a managed file and reference
    # it from settings.json. The home-relative path keeps the file
    # readable by Claude Code without dragging in the Nix store path.
    home.file.".claude/statusline-command.sh" = {
      text = cfg.script;
      executable = true;
    };

    programs.claude.settings.statusLine = {
      type = "command";
      command = "${config.home.homeDirectory}/.claude/statusline-command.sh";
      inherit (cfg) padding;
    };
  };
}
