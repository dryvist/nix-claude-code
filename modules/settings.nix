# Claude Code Settings (activation-time merge)
#
# Manages ~/.claude/settings.json and ~/.claude.json via activation-time merge
# (not home.file symlinks). Merges plugin marketplaces, permissions, hooks,
# MCP servers, etc.
#
# Uses `toClaudeMarketplaceFormat` from `lib/claude-registry.nix` as the
# single source of truth for marketplace format transformation.
#
# Environment variable names are validated at build time against POSIX
# convention (^[A-Z_][A-Z0-9_]*$). Full JSON Schema validation against
# https://json.schemastore.org/claude-code-settings.json is available via
# `nix flake check` but requires network access.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;

  claudeRegistry = import ../lib/claude-registry.nix { inherit lib; };
  inherit (claudeRegistry) toClaudeMarketplaceFormat;

  # Build the env attribute (merge user env vars with API_KEY_HELPER if enabled)
  envAttrs =
    cfg.settings.env
    // lib.optionalAttrs cfg.apiKeyHelper.enable {
      API_KEY_HELPER = "${homeDir}/${cfg.apiKeyHelper.scriptPath}";
    };

  # Validate POSIX environment variable names: ^[A-Z_][A-Z0-9_]*$
  isValidEnvVarName = name: builtins.match "^[A-Z_][A-Z0-9_]*$" name != null;
  invalidEnvVars = lib.filterAttrs (name: _: !isValidEnvVarName name) envAttrs;

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

  # `defaultMode` precedence (conflict resolution #4):
  #   1. cfg.settings.permissions.defaultMode (if non-null)  → wins
  #   2. cfg.defaultMode                                     → fallback
  resolvedDefaultMode =
    if cfg.settings.permissions.defaultMode != null then
      cfg.settings.permissions.defaultMode
    else
      cfg.defaultMode;

  # Auto-mode classifier configuration. Sub-fields exactly equal to the
  # literal default `[ "$defaults" ]` are filtered (they're semantically
  # a no-op — the classifier already uses defaults when unset). Only
  # surface autoMode in settings.json when at least one sub-field carries
  # caller-supplied content.
  autoModeAttrs =
    let
      isDefaultOnly = v: v == [ "$defaults" ];
      kept = lib.filterAttrs (_: v: !isDefaultOnly v) cfg.autoMode;
    in
    kept;

  # Build the settings object materialized into ~/.claude/settings.json.
  settings = {
    "$schema" = cfg.settings.schemaUrl;
    inherit (cfg.settings) alwaysThinkingEnabled cleanupPeriodDays skillListingBudgetFraction;
    inherit (cfg)
      autoUpdatesChannel
      teammateMode
      showTurnDuration
      ;
  }
  // lib.optionalAttrs (autoModeAttrs != { }) { autoMode = autoModeAttrs; }
  // lib.optionalAttrs (cfg.effortLevel != null) { inherit (cfg) effortLevel; }
  // lib.optionalAttrs (cfg.attribution != { }) { inherit (cfg) attribution; }
  // {
    permissions = {
      inherit (cfg.settings.permissions) allow deny ask;
      inherit (cfg.settings) additionalDirectories;
    }
    // lib.optionalAttrs (resolvedDefaultMode != null) {
      defaultMode = resolvedDefaultMode;
    };

    # Plugin marketplaces. Uses toClaudeMarketplaceFormat as the single
    # source of truth for the transformation.
    extraKnownMarketplaces = lib.mapAttrs toClaudeMarketplaceFormat cfg.plugins.marketplaces;

    enabledPlugins = cfg.plugins.enabled;
  }
  // lib.optionalAttrs (cfg.settings.skillOverrides != { }) {
    inherit (cfg.settings) skillOverrides;
  }
  // lib.optionalAttrs (cfg.model != null) { inherit (cfg) model; }
  // lib.optionalAttrs (cfg.remoteControlAtStartup != null) { inherit (cfg) remoteControlAtStartup; }
  // lib.optionalAttrs (envAttrs != { }) { env = envAttrs; }
  # Sandbox configuration (Dec 2025 feature)
  // lib.optionalAttrs cfg.settings.sandbox.enabled {
    sandbox = {
      inherit (cfg.settings.sandbox) enabled autoAllowBashIfSandboxed;
    }
    // lib.optionalAttrs (cfg.settings.sandbox.excludedCommands != [ ]) {
      inherit (cfg.settings.sandbox) excludedCommands;
    };
  };

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
      installLocation = "${homeDir}/.claude/plugins/marketplaces/${marketplaceName}";
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

  settingsJson =
    pkgs.runCommand "claude-settings.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        passAsFile = [ "json" ];
        json = builtins.toJSON settings;
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
        . ${./scripts/claude-json-merge.sh}
      '';

      claudeSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.jq}/bin:$PATH"
        $DRY_RUN_CMD ${./scripts/merge-json-settings.sh} \
          "${settingsJson}" \
          "${homeDir}/.claude/settings.json"
      '';

      knownMarketplacesMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.jq}/bin:$PATH"
        $DRY_RUN_CMD ${./scripts/merge-json-settings.sh} \
          "${knownMarketplacesJson}" \
          "${homeDir}/.claude/plugins/known_marketplaces.json"
      '';
    };

    # Validate configuration before generating settings.json
    assertions = [
      {
        assertion = invalidEnvVars == { };
        message = ''
          Invalid environment variable names in programs.claude.settings.env:
            ${lib.concatStringsSep ", " (builtins.attrNames invalidEnvVars)}

          Environment variable names must match POSIX convention: ^[A-Z_][A-Z0-9_]*$
          (uppercase letters, digits, and underscores only; must start with letter or underscore)
        '';
      }
    ];
  };
}
