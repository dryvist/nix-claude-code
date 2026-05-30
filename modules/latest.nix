# Auto-installer for the bleeding-edge Claude Code build at
# ~/.local/bin/claude. Coexists with whatever Claude Code binary is
# installed via the standard package (nix, brew, etc.).
#
# After the first install, Claude Code's own `claude update` command
# keeps the binary current. This module only bootstraps a missing
# install and exposes a manual `claude-latest-install` command.
#
# Web docs: https://claude.ai/install.sh
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude.latest;

  installScript = pkgs.writeShellApplication {
    name = "claude-latest-install";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
    ];
    text = builtins.readFile ./scripts/claude-latest-install.sh;
  };
in
{
  options.programs.claude.latest = {
    enable = lib.mkEnableOption ''
      auto-installer for the latest Claude Code release.
      Pulls the newest build outside of nixpkgs' release cycle.
      Opt-in: the default Claude Code binary comes from `programs.claude.package`.
    '';

    launchdLabel = lib.mkOption {
      type = lib.types.str;
      default = "sh.nix-claude-code.claude-latest-install";
      description = ''
        macOS LaunchAgent label. Override if you ship a fork or want to
        distinguish multiple installs.
      '';
    };
  };

  config = lib.mkIf (config.programs.claude.enable && cfg.enable && pkgs.stdenv.isDarwin) {
    # On PATH for manual re-install or forced re-run.
    home.packages = [ installScript ];

    # Fires once at login; no-op when already installed (script is idempotent).
    # KeepAlive = false: we only care about bootstrap, not a long-running service.
    launchd.agents.claude-latest-install = {
      enable = true;
      config = {
        Label = cfg.launchdLabel;
        ProgramArguments = [ "${installScript}/bin/claude-latest-install" ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/ClaudeLatest/install.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/ClaudeLatest/install.error.log";
      };
    };

    # Ensure the logs directory exists so launchd doesn't bail on first run.
    home.file."Library/Logs/ClaudeLatest/.keep".text = "";
  };
}
