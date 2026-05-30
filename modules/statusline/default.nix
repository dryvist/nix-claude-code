{ lib, ... }:
{
  imports = [
    ./powerline.nix
    ./ccstatusline.nix
    ./daniel3303.nix
    ./custom.nix

    # Back-compat for nix-ai callers that used `statusLine` (capital L).
    # The canonical option name here is `statusline` (lowercase) per the
    # rest of the module schema.
    (lib.mkRenamedOptionModule
      [ "programs" "claude" "statusLine" "enable" ]
      [ "programs" "claude" "statusline" "enable" ]
    )
    (lib.mkRenamedOptionModule
      [ "programs" "claude" "statusLine" "script" ]
      [ "programs" "claude" "statusline" "script" ]
    )
  ];

  options.programs.claude.statusline = {
    enable = lib.mkEnableOption "Claude Code statusline";

    theme = lib.mkOption {
      type = lib.types.enum [
        "powerline"
        "ccstatusline"
        "daniel3303"
        "custom"
      ];
      default = "powerline";
      description = ''
        Statusline theme. `powerline` (the default) uses
        `@owloops/claude-powerline` via `bunx`. `ccstatusline` uses
        `sirmalloc/ccstatusline` via `bunx`. `daniel3303` runs a local
        Bash fork of `daniel3303/ClaudeCodeStatusLine`. `custom` opts
        out of the built-in themes and uses the script body from
        `statusline.script` instead.
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

    script = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = ''
        Inline shell script body for a custom statusline. When set,
        rendered to `~/.claude/statusline-command.sh` and wired into
        `settings.json`'s `statusLine` block. Set `theme = "custom"`
        to opt into this path explicitly.
      '';
    };
  };
}
