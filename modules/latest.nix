{ config, lib, ... }:
let
  cfg = config.programs.claude.latest;
in
{
  options.programs.claude.latest = {
    enable = lib.mkEnableOption ''
      auto-installer for the latest Claude Code release.
      Pulls the newest build outside of nixpkgs' release cycle.
      Opt-in: the default Claude Code binary comes from `programs.claude.package`.
    '';
  };

  config = lib.mkIf (config.programs.claude.enable && cfg.enable) {
    # Stub: latest-installer lands in Checkpoint 1.
  };
}
