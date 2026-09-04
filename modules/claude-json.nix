# Global config overlays (activation-time merge)
#
# Manages the runtime-mutable global files OUTSIDE settings.json: .claude.json
# (MCP servers, remote control, auto-updates) and
# `configDir`/plugins/known_marketplaces.json (Nix-managed marketplaces).
# The settings.json builder lives in `settings.nix`. See `claudeJsonPath`
# below for exactly where .claude.json lives relative to `configDir`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;

  claudeRegistry = import ../lib/claude-registry.nix {
    inherit lib homeDir;
    inherit (cfg) configDir;
  };
  inherit (claudeRegistry) toClaudeMarketplaceFormat;

  # .claude.json is a special case relative to everything else this module
  # writes: at the default configDir, upstream keeps it a SIBLING of
  # ~/.claude at $HOME/.claude.json, not nested inside it. But once
  # CLAUDE_CONFIG_DIR points elsewhere, observed (undocumented — see
  # https://github.com/anthropics/claude-code/issues/3833) upstream behavior
  # moves it INSIDE that directory. Mirrored here so Nix and the real binary
  # agree on where it lives; not a plain prefix swap.
  claudeJsonPath =
    if cfg.configDir == ".claude" then
      "${homeDir}/.claude.json"
    else
      "${cfg.configDirAbs}/.claude.json";

  # Same wrapper as settings.nix — identical name+text, so both modules
  # resolve to one store path; see settings.nix for why writeShellApplication.
  mergeJsonSettings = pkgs.writeShellApplication {
    name = "merge-json-settings";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./scripts/merge-json-settings.sh;
  };

  # Build Claude Code JSON for enabled (non-disabled) MCP servers.
  activeMcpServers = lib.filterAttrs (_: v: !v.disabled) cfg.mcpServers;
  mcpServersAttrs = lib.mapAttrs (
    _: v:
    if v.type == "stdio" then
      { inherit (v) command args; } // lib.optionalAttrs (v.env != { }) { inherit (v) env; }
    else
      { inherit (v) type url; } // lib.optionalAttrs (v.headers != { }) { inherit (v) headers; }
  ) activeMcpServers;

  # Static JSON overlay merged into ~/.claude.json at activation time.
  claudeJsonOverlay = {
    mcpServers = mcpServersAttrs;
  }
  // lib.optionalAttrs (cfg.remoteControlAtStartup != null) {
    inherit (cfg) remoteControlAtStartup;
  }
  // lib.optionalAttrs (cfg.autoUpdates != null) {
    inherit (cfg) autoUpdates;
  };

  claudeJsonOverlayFile =
    pkgs.runCommand "claude-json-overlay.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        passAsFile = [ "json" ];
        json = builtins.toJSON claudeJsonOverlay;
      }
      ''
        jq '.' "$jsonPath" > $out
      '';

  # All Nix-managed marketplaces need entries in known_marketplaces.json
  # so Claude Code reads them from the Nix-managed symlink instead of
  # fetching them from GitHub at runtime.
  nixManagedMarketplaces = lib.filterAttrs (_: m: m.flakeInput != null) cfg.plugins.marketplaces;
  knownMarketplacesOverlay = lib.mapAttrs (
    name: m:
    let
      formatted = toClaudeMarketplaceFormat name m;
      marketplaceName = lib.last (lib.splitString "/" name);
    in
    {
      inherit (formatted) source;
      installLocation = "${cfg.configDirAbs}/plugins/marketplaces/${marketplaceName}";
      lastUpdated = "1970-01-01T00:00:00.000Z";
    }
  ) nixManagedMarketplaces;

  knownMarketplacesJson =
    pkgs.runCommand "known-marketplaces-overlay.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        passAsFile = [ "json" ];
        json = builtins.toJSON knownMarketplacesOverlay;
      }
      ''
        jq '.' "$jsonPath" > $out
      '';
in
{
  config = lib.mkIf cfg.enable {
    # Merge runtime keys into ~/.claude.json (global config) at activation time.
    # These keys live in the global config file (not settings.json), so home.file
    # cannot be used directly — the file is runtime-mutable. One unified script
    # deep-merges all keys.
    home.activation = {
      claudeJsonMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.jq}/bin:$PATH"
        OVERLAY_FILE="${claudeJsonOverlayFile}"
        TRUSTED_PROJECT_DIRS=${lib.escapeShellArg (builtins.toJSON cfg.trustedProjectDirs)}
        CLAUDE_JSON="${claudeJsonPath}"
        . ${./scripts/claude-json-merge.sh}
      '';

      knownMarketplacesMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${mergeJsonSettings}/bin/merge-json-settings \
          "${knownMarketplacesJson}" \
          "${cfg.configDirAbs}/plugins/known_marketplaces.json"
      '';
    };
  };
}
