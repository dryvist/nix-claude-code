{ config, lib, ... }:
let
  cfg = config.programs.claude.statusline;
in
{
  options.programs.claude.statusline = {
    enable = lib.mkEnableOption "Claude Code statusline";

    theme = lib.mkOption {
      type = lib.types.enum [
        "powerline"
        "ccstatusline"
        "daniel3303"
      ];
      default = "powerline";
      description = ''
        Statusline theme. `powerline` is the default; `ccstatusline` and
        `daniel3303` are alternative community themes.
      '';
    };
  };

  config = lib.mkIf (config.programs.claude.enable && cfg.enable) {
    # Stub: theme wiring lands in Checkpoint 1.
  };
}
