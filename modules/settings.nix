# Claude Code Settings (activation-time merge)
#
# Manages ~/.claude/settings.json via activation-time merge (not home.file
# symlinks). Merges plugin marketplaces, permissions, hooks, etc.
# The ~/.claude.json and known_marketplaces.json overlays live in
# `claude-json.nix`.
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

  claudeRegistry = import ../lib/claude-registry.nix { inherit lib homeDir; };
  inherit (claudeRegistry) toClaudeMarketplaceFormat;
  hookEventMapping = import ../lib/hook-event-mapping.nix;

  # Register each configured typed hook (modules/hooks.nix writes the
  # script file; this makes Claude Code actually invoke it) under its
  # Claude Code event name. `cfg.settings.hooks` (freeform passthrough)
  # is merged on top so a caller-supplied entry for the same event wins.
  typedHooksAttrs = lib.mapAttrs' (
    _hookName: mapping:
    lib.nameValuePair mapping.claudeEvent [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "${homeDir}/.claude/hooks/${mapping.fileName}";
          }
        ];
      }
    ]
  ) (lib.filterAttrs (hookName: _: cfg.hooks.${hookName} != null) hookEventMapping);

  # `hooks` is freeform (no typed option), so an unset value must be
  # accessed with `or { }` — the submodule attrset only materializes keys
  # a caller actually set.
  hooksAttrs = typedHooksAttrs // (cfg.settings.hooks or { });

  # Directories every adopter needs Claude Code to reach without prompting.
  # `~/.claude/` is Claude's own config/plugin tree; `/tmp/` covers scratch
  # files agents commonly write. See `additionalDirectories` in the
  # `permissions` block below for how these merge with caller entries.
  universalAdditionalDirectories = [
    "~/.claude/"
    "/tmp/"
  ];

  # Wrap merge-json-settings.sh in a writeShellApplication so the Nix store
  # copy carries the executable bit, has jq on PATH, and passes shellcheck.
  # Path interpolation (`${./scripts/merge-json-settings.sh}`) preserves the
  # source git mode (0644), which produces a non-executable store path —
  # direct exec then fails with EACCES and aborts activation under set -e.
  mergeJsonSettings = pkgs.writeShellApplication {
    name = "merge-json-settings";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./scripts/merge-json-settings.sh;
  };

  validateSettings = pkgs.writeShellApplication {
    name = "validate-claude-settings";
    text = builtins.readFile ./scripts/validate-settings.sh;
  };

  # Sensible env defaults every adopter benefits from (MCP timeouts long
  # enough for slow servers, deferred MCP tool-schema loading, agent teams).
  # Merged *under* `cfg.settings.env` so overriding any single key wins
  # per-key rather than requiring the whole map to be redeclared.
  upstreamEnvDefaults = {
    MCP_TIMEOUT = "300000";
    MCP_TOOL_TIMEOUT = "300000";
    ENABLE_TOOL_SEARCH = "auto:10";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
  };

  # autoCompactThresholdPercent is a curated option (options-settings.nix),
  # not a real settings.json key — Claude Code only exposes this via the
  # CLAUDE_AUTOCOMPACT_PCT_OVERRIDE env var. Merged before cfg.settings.env
  # so a caller-supplied raw env entry for the same var still wins.
  autoCompactEnv = lib.optionalAttrs (cfg.settings.autoCompactThresholdPercent != null) {
    CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = toString cfg.settings.autoCompactThresholdPercent;
  };

  # Build the env attribute (merge upstream defaults, the auto-compact
  # threshold, user env vars, and API_KEY_HELPER if enabled — later entries
  # win on key conflict).
  envAttrs =
    upstreamEnvDefaults
    // autoCompactEnv
    // cfg.settings.env
    // lib.optionalAttrs cfg.apiKeyHelper.enable {
      API_KEY_HELPER = "${homeDir}/${cfg.apiKeyHelper.scriptPath}";
    };

  # Build-time validation (env-var names, autoCompact range, the empty-`ask`
  # rule, and the five-minute human-wait cap). Split into its own file to
  # keep this one under the repo's per-file size limit.
  settingsAssertions = import ./settings-assertions.nix { inherit lib cfg envAttrs; };

  # `defaultMode` precedence (conflict resolution #4):
  #   1. cfg.settings.permissions.defaultMode (if non-null)  → wins
  #   2. cfg.defaultMode                                     → fallback
  resolvedDefaultMode =
    if cfg.settings.permissions.defaultMode != null then
      cfg.settings.permissions.defaultMode
    else
      cfg.defaultMode;

  # `outputStyle` precedence:
  #   1. cfg.settings.outputStyle (if non-null)  → wins
  #   2. cfg.outputStyle                         → fallback
  resolvedOutputStyle =
    if cfg.settings.outputStyle != null then cfg.settings.outputStyle else cfg.outputStyle;

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

  # Freeform passthrough: keys set on cfg.settings that the builder does not
  # model explicitly (e.g. statusLine from the statusline submodules, or the
  # curated catalog in options-settings.nix like `editorMode`) flow through
  # verbatim. Restores the contract documented in options-settings.nix after
  # the #39 settings.json rewrite dropped it.
  #
  # This list must mirror the top-level named options in options-settings.nix
  # that this builder emits *explicitly* below. Curated `nullOr` options are
  # deliberately NOT added here — they ride this freeform path instead, and
  # the null-filter is what keeps their default (unset) from ever emitting.
  # Exception: `autoCompactThresholdPercent` IS listed here even though it's
  # a curated `nullOr` option, because it has no settings.json key of its
  # own — it's consumed above into `autoCompactEnv`/`envAttrs` instead, so
  # letting it ride freeform would leak a bogus top-level JSON key.
  # `hooks` is also listed here (unlike the freeform-only convention its
  # comment above describes) because it needs the typed-hooks merge above,
  # not a verbatim passthrough — see `hooksAttrs`.
  knownSettingsKeys = [
    "alwaysThinkingEnabled"
    "cleanupPeriodDays"
    "skillListingBudgetFraction"
    "skillOverrides"
    "permissions"
    "additionalDirectories"
    "env"
    "schemaUrl"
    "sandbox"
    "autoCompactThresholdPercent"
    "hooks"
    "outputStyle"
  ];
  # Null-valued keys are dropped so a curated option left at its `null`
  # ("use Claude's upstream default") default is omitted from the generated
  # settings.json entirely, rather than emitted as an explicit `null`.
  freeformSettings = lib.filterAttrs (_: v: v != null) (
    builtins.removeAttrs cfg.settings knownSettingsKeys
  );

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
  // lib.optionalAttrs (hooksAttrs != { }) { hooks = hooksAttrs; }
  // {
    permissions = {
      inherit (cfg.settings.permissions) allow deny ask;
      # Universal directories every adopter needs Claude Code to reach
      # without prompting (its own config dir, and /tmp for scratch files),
      # concatenated with caller-supplied entries. `lib.unique` keeps the
      # merged list clean if a caller redundantly lists one of these too.
      additionalDirectories = lib.unique (
        map (lib.removeSuffix "/") (universalAdditionalDirectories ++ cfg.settings.additionalDirectories)
      );
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
  // lib.optionalAttrs (resolvedOutputStyle != null) { outputStyle = resolvedOutputStyle; }
  // lib.optionalAttrs (cfg.remoteControlAtStartup != null) { inherit (cfg) remoteControlAtStartup; }
  // lib.optionalAttrs (envAttrs != { }) { env = envAttrs; }
  # Sandbox configuration (Dec 2025 feature).
  #
  # Emit every sub-key the caller actually set, rather than three by name.
  # `sandbox` is in `knownSettingsKeys`, so the whole attrset is removed from
  # `freeformSettings` — naming keys individually here meant anything else a
  # caller configured, including the `network` and `filesystem` policies that
  # decide what the sandbox contains, was silently dropped instead of reaching
  # settings.json.
  #
  # Nulls and empty lists are filtered for the same reason they are in
  # `freeformSettings`: an option left at its `null` default means "use
  # Claude's upstream default", which is expressed by omitting the key. This
  # preserves the previous behaviour for `excludedCommands`, whose empty
  # default was likewise omitted.
  // lib.optionalAttrs cfg.settings.sandbox.enabled {
    sandbox = lib.filterAttrs (_: v: v != null && v != [ ]) cfg.settings.sandbox;
  }
  // freeformSettings;

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
    home.activation = {
      claudeSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${mergeJsonSettings}/bin/merge-json-settings \
          "${settingsJson}" \
          "${homeDir}/.claude/settings.json"
      '';
    }
    // lib.optionalAttrs cfg.validateSettings.enable {
      # Warn-only schema check; runs after the merge above so it validates
      # the actual deployed file, not just the Nix-generated overlay.
      validateClaudeSettings = lib.hm.dag.entryAfter [ "claudeSettingsMerge" ] ''
        $DRY_RUN_CMD ${validateSettings}/bin/validate-claude-settings \
          "${homeDir}/.claude/settings.json" \
          "${cfg.settings.schemaUrl}"
      '';
    };

    # Validate configuration before generating settings.json
    assertions = settingsAssertions;
  };
}
