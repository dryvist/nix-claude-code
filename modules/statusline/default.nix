{ lib, ... }:
{
  imports = [
    ./powerline.nix
    ./ccstatusline.nix
    ./daniel3303.nix
  ];

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
        Statusline theme. `powerline` (the default) uses
        `@owloops/claude-powerline` via `bunx`. `ccstatusline` uses
        `sirmalloc/ccstatusline` via `bunx`. `daniel3303` runs a local
        Bash fork of `daniel3303/ClaudeCodeStatusLine`.
      '';
    };

    padding = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = ''
        Padding (number of spaces) to apply to the rendered statusline.
        Surfaced into `~/.claude/settings.json`'s `statusLine.padding`
        field per Anthropic's spec.
      '';
    };
  };
}
