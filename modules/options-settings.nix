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
      # Curated catalog of documented-but-untyped-elsewhere settings.json
      # keys (all nullOr, opt-in) — split out to keep this file under the
      # 12KB file-size limit.
      imports = [ ./options-settings-catalog.nix ];
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
        #
        # These lists ARE what `./settings.nix` renders into
        # `~/.claude/settings.json` — the top-level
        # `programs.claude.permissions` option in `./core.nix` is a
        # structured input for `lib.toSettingsJson` callers and is not read
        # by the renderer.
        #
        # All three default to `[ ]` by design. This module ships no
        # hard-coded rules: `programs.claude.defaultMode` is `"auto"`, so
        # the auto-mode classifier evaluates every call in context. The
        # lists stay settable for adopters who need a hard boundary the
        # classifier cannot express, with one exception — see the `ask`
        # option and the assertion in `./settings.nix`.
        permissions = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            freeformType = lib.types.attrs;
            options = {
              allow = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Commands and operations to auto-approve without
                  prompting. Empty by design — an allow rule resolves
                  before the classifier and so removes an action from its
                  review. `autoMode.classifyAllShell` additionally
                  suspends shell allow rules while auto mode is active.
                '';
              };
              deny = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Commands and operations to permanently block. Blocks
                  before the classifier is consulted and cannot be
                  overridden by user intent. Empty by design; a deny entry
                  does not stall a session, so this is the one list that is
                  safe to populate when you need an absolute boundary.
                '';
              };
              ask = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Commands and operations requiring user confirmation.

                  Must stay empty: an ask rule is evaluated BEFORE the
                  classifier and always forces a permission prompt, even in
                  auto mode, so it is the one rule class that can stall a
                  session waiting on a human. `./settings.nix` asserts this
                  list is empty. Use `deny` for a hard boundary instead.
                '';
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
          example = "60s";
          description = ''
            Idle time before an unanswered `AskUserQuestion` dialog
            auto-continues with whatever options are already selected.
            Accepts "60s" or "5m" style values.

            Upstream's default is "never" — an unanswered dialog blocks
            forever. Five minutes is the deliberate cap for this module, and
            `./settings.nix` asserts the value never exceeds it (and rejects
            "never"), so no dialog can hold a session open indefinitely.
          '';
        };

        dialogExpiry = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "60s";
          description = ''
            Deadline for dialogs Claude Code forwards to a remote client
            (Remote Control, SDK hosts) — model-choice prompts after a
            safety refusal, approval dialogs for held cross-session
            messages. Accepts "60s" or "5m" style values.

            `null` (the default) leaves Claude Code's own default of "5m",
            which is already within this module's five-minute cap, so we do
            not override it. Set it only to go LOWER: `./settings.nix`
            asserts a non-null value never exceeds 5m. Requires Claude Code
            v2.1.224 or later.
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

        advisorModel = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "opus";
          description = ''
            Configure a persistent default advisor model. null = upstream
            default (unset).
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
