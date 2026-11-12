# Builder-merged `env` defaults for the generated settings.json.
#
# Split out of ./settings.nix to keep that file under the 12KB per-file
# size gate. Entries merge left-to-right with later entries winning per
# key: upstream defaults, then the curated auto-compact options and the
# subagent pin, then `programs.claude.settings.env`, then API_KEY_HELPER
# — so a caller overrides any single variable without redeclaring the
# rest, and the raw-env entry always beats the curated-option render for
# the same variable.
{
  lib,
  cfg,
  homeDir,
}:
let
  # Env defaults: MCP timeouts, deferred MCP tool-schema loading, and the
  # Bash tool's default (60s) and maximum (300s) timeouts.
  # ENABLE_TOOL_SEARCH=true always defers MCP schemas; an `auto:N` threshold
  # loads them all upfront until they pass N% of the window, which on a
  # 1M-token window is never.
  upstreamEnvDefaults = {
    MCP_TIMEOUT = "300000";
    MCP_TOOL_TIMEOUT = "300000";
    ENABLE_TOOL_SEARCH = "true";
    BASH_DEFAULT_TIMEOUT_MS = "60000";
    BASH_MAX_TIMEOUT_MS = "300000";
  };

  # autoCompactThresholdPercent is a curated option (options-settings.nix),
  # not a real settings.json key — Claude Code only exposes this via the
  # CLAUDE_AUTOCOMPACT_PCT_OVERRIDE env var. Merged before cfg.settings.env
  # so a caller-supplied raw env entry for the same var still wins.
  autoCompactEnv =
    lib.optionalAttrs (cfg.settings.autoCompactThresholdPercent != null) {
      CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = toString cfg.settings.autoCompactThresholdPercent;
    }
    // lib.optionalAttrs (cfg.settings.autoCompactWindow != null) {
      CLAUDE_CODE_AUTO_COMPACT_WINDOW = cfg.settings.autoCompactWindow;
    };

  # Subagent model pinning (options-subagents.nix). With
  # CLAUDE_CODE_SUBAGENT_MODEL_FORCE = "1", Claude Code v2.1.257+ applies
  # CLAUDE_CODE_SUBAGENT_MODEL to every subagent, teammate, and workflow
  # agent, and CLAUDE_CODE_FORK_SUBAGENT = "0" keeps forks — which inherit
  # the main session's model — off. settings-assertions.nix holds the
  # rendered values to this. Merged before cfg.settings.env so a
  # caller-supplied raw env entry for the same var still wins.
  subagentEnv = {
    CLAUDE_CODE_SUBAGENT_MODEL = cfg.settings.subagentModel;
    CLAUDE_CODE_SUBAGENT_MODEL_FORCE = if cfg.settings.forceSubagentModel then "1" else "0";
    CLAUDE_CODE_FORK_SUBAGENT = if cfg.settings.forkSubagents then "1" else "0";
  };
in
upstreamEnvDefaults
// autoCompactEnv
// subagentEnv
// cfg.settings.env
// lib.optionalAttrs cfg.apiKeyHelper.enable {
  API_KEY_HELPER = "${homeDir}/${cfg.apiKeyHelper.scriptPath}";
}
