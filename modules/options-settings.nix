# Claude Code Module — `settings.json` option declarations
#
# Everything that lands inside the deployed `settings.json`: thinking mode,
# session cleanup, skill-listing budget, permissions, accessible directories,
# environment variables, schema URL, and sandbox configuration.
#
# The option set is wrapped in a submodule with `freeformType = attrs` so
# callers can also pass arbitrary keys that are merged into settings.json
# verbatim (e.g. `programs.claude.settings.statusLine = {...}` used by
# the statusline sub-modules).
{ lib, ... }:
{
  options.programs.claude.settings = lib.mkOption {
    default = { };
    description = ''
      Contents of `~/.claude/settings.json`. Module-generated values
      (permissions, plugins, mcpServers, statusLine) are merged first;
      entries here override them. Sub-options below cover the
      well-known schema fields; arbitrary keys are accepted via the
      freeform submodule type.
    '';
    type = lib.types.submodule {
      freeformType = lib.types.attrs;
      options = {
        # Extended thinking mode
        alwaysThinkingEnabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable Claude's extended thinking capability by default.
            When enabled, Claude can reason through complex problems step-by-step.
            Token budget controlled by MAX_THINKING_TOKENS in env.
          '';
        };

        # Session management
        cleanupPeriodDays = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = ''
            Sessions inactive longer than this period are deleted.
            Upstream Claude default is 30 days.
          '';
        };

        # Skill listing budget
        skillListingBudgetFraction = lib.mkOption {
          type = lib.types.float;
          default = 0.02;
          description = ''
            Fraction of the context window reserved for skill descriptions.
            Upstream default is 0.01 (1%); 0.02 gives more headroom for
            larger plugin sets.
          '';
        };

        # Per-skill visibility overrides
        skillOverrides = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.enum [
              "on"
              "name-only"
              "user-invocable-only"
              "off"
            ]
          );
          default = { };
          example = {
            "django-pro" = "off";
            "saga-orchestration" = "name-only";
          };
          description = "Per-skill visibility overrides for personal/project/managed skills.";
        };

        # Permissions (raw lists merged into settings.json).
        # Note: the top-level `programs.claude.permissions` option (declared
        # in `./core.nix`) is the structured input to `lib.toSettingsJson`
        # and is the canonical entrypoint. The `settings.permissions.*`
        # lists below are an additional, lower-level escape hatch and
        # remain valid input.
        permissions = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            freeformType = lib.types.attrs;
            options = {
              allow = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Commands and operations to auto-approve without prompting";
              };
              deny = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Commands and operations to permanently block";
              };
              ask = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Commands and operations requiring user confirmation";
              };
              defaultMode = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "acceptEdits"
                    "auto"
                    "bypassPermissions"
                    "default"
                    "dontAsk"
                    "plan"
                  ]
                );
                default = null;
                description = ''
                  When set, overrides the top-level `programs.claude.defaultMode`
                  for the generated `settings.json`. Leave as `null` to defer
                  to the top-level option.
                '';
              };
            };
          };
        };

        additionalDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Directories accessible to Claude Code without prompts";
          example = [
            "~/projects"
            "~/Documents"
            "~/.config"
          ];
        };

        # Environment variables for Claude Code
        # See: https://code.claude.com/docs/en/settings
        env = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Environment variables passed to Claude Code.";
          example = {
            MAX_THINKING_TOKENS = "16000";
            CLAUDE_CODE_MAX_OUTPUT_TOKENS = "16000";
          };
        };

        schemaUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://json.schemastore.org/claude-code-settings.json";
          description = "JSON schema URL for settings validation";
        };

        # Plan mode / interactive-prompt UX. Both default to non-null values
        # (rather than following the "unset = upstream default" convention
        # below) because the upstream defaults are surprising in practice:
        # `askUserQuestionTimeout` docs claim a default, but the real runtime
        # default is "never" (an unanswered dialog blocks forever), and plan
        # mode otherwise runs at the session's ordinary mode rather than the
        # (usually cheaper/faster) auto mode classifier.
        askUserQuestionTimeout = lib.mkOption {
          type = lib.types.str;
          default = "5m";
          example = "10m";
          description = ''
            Idle time before an unanswered `AskUserQuestion` dialog
            auto-continues. Accepts "60s", "5m", "10m", or "never".
            Despite upstream docs, the real runtime default is "never"
            (blocks forever) — set explicitly to avoid stalled sessions.
          '';
        };

        useAutoModeDuringPlan = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Use the auto-mode permission classifier while in plan mode,
            instead of plan mode's own (more restrictive) tool gating.
          '';
        };

        # Curated catalog of documented settings.json keys with no typed
        # home elsewhere in this module. All default to `null` (omitted from
        # the generated settings.json — see `freeformSettings` in
        # `./settings.nix`) so setting one is opt-in and leaves Claude's own
        # upstream default untouched until a caller overrides it.
        # See: https://code.claude.com/docs/en/settings
        autoCompactEnabled = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Automatically compact the conversation as context approaches
            the limit. null = upstream default (`true`).
          '';
        };

        # Not a settings.json key (Claude Code exposes no such key — see
        # https://github.com/anthropics/claude-code/issues/46695). Rides the
        # curated catalog for discoverability/validation, but is consumed by
        # ./settings.nix into the CLAUDE_AUTOCOMPACT_PCT_OVERRIDE env var
        # rather than emitted as a top-level JSON key (see knownSettingsKeys
        # in ./settings.nix). Deliberately defaults to a repo opinion (60)
        # rather than null/upstream — context windows are trending toward 1M
        # tokens, and Claude's own default (~90%+ of window) leaves too
        # little headroom for the summarization pass itself at that scale.
        autoCompactThresholdPercent = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = 60;
          example = 60;
          description = ''
            Percent of the context window used at which auto-compaction
            fires. Lower = compact sooner with more headroom for the
            summarization pass; at 60% a 1M-token window still leaves ~600K
            tokens of working space.

            Emitted as the `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` environment
            variable in the `env` block — setting
            `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` directly overrides this
            option. `null` = omit entirely (Claude's upstream default,
            ~90%+). Only applies when `autoCompactEnabled` is not `false`.
          '';
        };

        outputStyle = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Output style adjusting Claude's system prompt (e.g.
            "Explanatory", "Learning"). null = upstream default (unset).
          '';
        };

        includeCoAuthoredBy = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Include Claude co-author trailers in git commits. null =
            upstream default (`true`). See also `programs.claude.attribution`
            for the free-form commit/PR trailer strings.
          '';
        };

        enableAllProjectMcpServers = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Automatically approve all MCP servers declared in project
            `.mcp.json` files, skipping the per-server approval prompt.
            null = upstream default (`false`).
          '';
        };

        editorMode = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "normal"
              "vim"
            ]
          );
          default = null;
          description = ''
            Key-binding mode for the input prompt. null = upstream default
            (`"normal"`).
          '';
        };

        includeGitInstructions = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Include the built-in commit/PR workflow instructions and git
            status snapshot in the system prompt. null = upstream default
            (`true`).
          '';
        };

        fileCheckpointingEnabled = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = ''
            Snapshot files before each edit so `/rewind` can restore them.
            null = upstream default (`true`).
          '';
        };

        plansDirectory = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Directory where plan-mode files are stored. null = upstream
            default (`~/.claude/plans`).
          '';
        };

        language = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Claude's preferred response language; also sets voice dictation
            and auto-title language. null = upstream default (unset,
            follows conversation language).
          '';
        };

        fallbackModel = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = ''
            Fallback model(s) tried in order when the primary model is
            overloaded (capped at 3 upstream). null = upstream default
            (unset, no fallback).
          '';
        };

        # Sandbox configuration (Dec 2025 feature)
        sandbox = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            freeformType = lib.types.attrs;
            options = {
              enabled = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable sandbox mode for filesystem/network isolation.";
              };
              autoAllowBashIfSandboxed = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Automatically allow bash commands when sandboxed.";
              };
              excludedCommands = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Commands to exclude from sandbox restrictions";
                example = [
                  "git"
                  "nix"
                  "darwin-rebuild"
                ];
              };
            };
          };
        };
      };
    };
  };
}
