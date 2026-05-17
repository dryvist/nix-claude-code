{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude.statusline;
  active = config.programs.claude.enable && cfg.enable && cfg.theme == "ccstatusline";

  configFile = ./ccstatusline.json;

  script = pkgs.writeShellScript "claude-ccstatusline" ''
    # sirmalloc/ccstatusline (semver-pinned for stability)
    export PATH="${pkgs.git}/bin:$PATH"
    exec ${pkgs.bun}/bin/bunx ccstatusline@'^2' --config ${configFile} "$@"
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
