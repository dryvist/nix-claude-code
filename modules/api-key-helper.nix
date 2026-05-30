# Claude Code API Key Helper
#
# Optional Bitwarden Secrets Manager integration for headless Claude Code
# authentication (cron jobs, CI, launchd, etc). Opt in via:
#
#   programs.claude.apiKeyHelper.enable = true;
#
# The user supplies their own BWS env file at `~/.config/bws/.env`; this
# module ships a `.env.example` template alongside.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude;

  # Bundle get-api-key.py + bws_helper.py into a single Nix store directory
  # so Path(__file__).parent in get-api-key.py resolves bws_helper correctly.
  # linkFarm creates a directory of symlinks — more idiomatic than runCommand cp.
  apiKeyHelperSrc = pkgs.linkFarm "claude-api-key-helper-src" [
    {
      name = "get-api-key.py";
      path = ./api-key-helper/get-api-key.py;
    }
    {
      name = "bws_helper.py";
      path = ./api-key-helper/bws_helper.py;
    }
  ];

  # Wrap get-api-key.py as a self-contained shell app.
  # runtimeInputs injects python+keyring+bws into PATH only when the wrapper
  # runs — this avoids adding a python3.withPackages env to home.packages,
  # which conflicts with consumers that already build their own python env.
  apiKeyHelperBin = pkgs.writeShellApplication {
    name = "claude-api-key-helper";
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ ps.keyring ]))
      pkgs.bws
    ];
    text = ''
      exec python3 ${apiKeyHelperSrc}/get-api-key.py "$@"
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.apiKeyHelper.enable) {
    home.file = {
      # API Key Helper: symlink the wrapper binary to scriptPath so
      # settings.json can reference it at its stable home-relative location.
      "${cfg.apiKeyHelper.scriptPath}" = {
        source = "${apiKeyHelperBin}/bin/claude-api-key-helper";
        executable = true;
      };

      # Template for ~/.config/bws/.env that bws_helper.py reads
      ".config/bws/.env.example" = {
        source = ./api-key-helper/bws-env.example;
      };
    };
  };
}
