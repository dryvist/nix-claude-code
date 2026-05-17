{
  config,
  lib,
  pkgs,
  ...
}:
# daniel3303 statusline: local Bash fork of
# https://github.com/daniel3303/ClaudeCodeStatusLine.
#
# The fork is `./claude-statusline.sh`. Only deviation from upstream is
# the cwd-formatter (last 2 path components instead of basename only).
let
  cfg = config.programs.claude.statusline;
  active = config.programs.claude.enable && cfg.enable && cfg.theme == "daniel3303";

  statuslineScript = ./claude-statusline.sh;

  # Runtime tools the Bash script shells out to. Listed in `lib.makeBinPath`
  # order so the explicit prefix matches whatever the user has on $PATH at
  # invocation time without surprising them.
  runtimePath = lib.makeBinPath [
    pkgs.bash
    pkgs.jq
    pkgs.git
    pkgs.curl
    pkgs.gawk
    pkgs.coreutils
  ];

  script = pkgs.writeShellScript "claude-statusline-daniel3303" ''
    export PATH="${runtimePath}:$PATH"
    exec ${pkgs.bash}/bin/bash ${statuslineScript} "$@"
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
