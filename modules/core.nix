{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude;
in
{
  options.programs.claude = {
    enable = lib.mkEnableOption "Claude Code as a declarative home-manager module";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.claude-code or null;
      defaultText = lib.literalExpression "pkgs.claude-code";
      description = ''
        The Claude Code package. Set to `null` to skip installing the binary
        (useful if you manage Claude Code via Homebrew or another channel).
      '';
    };

    permissions = lib.mkOption {
      # Either an attrset (the structured input `lib.toSettingsJson`
      # consumes) or `false` to write no rule lists at all.
      type = lib.types.either lib.types.attrs (lib.types.enum [ false ]);
      default = false;
      description = ''
        Structured permission input for `lib.toSettingsJson`. Defaults to
        `false`: this module deliberately ships NO hard-coded allow, ask,
        or deny rules for Claude Code. The auto-mode classifier
        (`defaultMode = "auto"`) is the only gate — it reads the
        conversation, the working repo, and CLAUDE.md, so it can weigh a
        command in context where a prefix list cannot.

        The vendored rule data still exists and is still exported as
        `lib.mkDefaultPermissions` for tools that have no classifier
        (Codex, Gemini); it is simply not consumed on the Claude path.

        Note: this option is not read by the `settings.json` renderer —
        `programs.claude.settings.permissions.*` is. It remains declared
        for API compatibility with adopters that pass it through to
        `lib.toSettingsJson` themselves.
      '';
    };

    defaultMode = lib.mkOption {
      type = lib.types.enum [
        "default"
        "acceptEdits"
        "plan"
        "auto"
        "bypassPermissions"
      ];
      default = "auto";
      description = ''
        Default Claude Code permission mode. Lands at
        `permissions.defaultMode` in settings.json. Equivalent to running
        `claude --permission-mode auto`.

        "auto" is the default and the posture this module is built around:
        every tool call that no explicit rule resolves is routed to the
        auto-mode classifier, which evaluates it against its own built-in
        rule set plus anything in `programs.claude.autoMode`. A denial is
        returned to Claude as a blocked tool call, so the session keeps
        working rather than waiting on a human.

        Claude Code only honours `"auto"` from USER settings
        (`~/.claude/settings.json`) or managed settings — it is ignored in
        a repo's `.claude/settings.json` so a checked-in repo cannot grant
        itself auto mode. This module writes user settings, so the value
        takes effect.

        "bypassPermissions" (also reachable via the
        `--dangerously-skip-permissions` CLI flag) skips every check
        except `permissions.deny` and credential-read protection, and gets
        no classifier review at all. Prefer "auto".
      '';
    };

    autoMode = lib.mkOption {
      type = lib.types.submodule {
        options = {
          environment = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "$defaults" ];
            description = ''
              Trusted infrastructure entries the auto-mode classifier
              treats as internal. Prose strings, read as natural-language
              rules. Include `"$defaults"` to inherit the built-in
              entries (current working repo + configured remotes) and
              splice your entries before/after.
            '';
          };
          allow = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "$defaults" ];
            description = ''
              Exceptions to `soft_deny` rules. Prose strings. Include
              `"$defaults"` to inherit built-ins.
            '';
          };
          soft_deny = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "$defaults" ];
            description = ''
              Destructive actions blocked unless overridden by explicit
              user intent or an `allow` entry. Include `"$defaults"` to
              inherit the built-in soft-block list (force-push,
              `curl | bash`, production deploys, etc.).
            '';
          };
          hard_deny = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "$defaults" ];
            description = ''
              Unconditional blocks. Include `"$defaults"` to inherit the
              built-in list (data exfiltration patterns, auto-mode bypass
              attempts, etc.).
            '';
          };
          classifyAllShell = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Suspend every Bash and PowerShell allow rule while auto mode
              is active, so the classifier sees every shell command
              regardless of what the allow list says.

              Defaults to `true` here. This module emits no allow rules of
              its own, so on a clean machine the setting is a no-op — but
              `~/.claude/settings.json` is a writable runtime file, and a
              narrow allow rule that reaches it from outside Nix would
              otherwise resolve before the classifier ever runs. Setting
              this keeps "the classifier decides" true regardless of what
              lands in the file.

              Trades latency for coverage: a command an allow rule would
              have approved instantly now waits for a classifier verdict.
              Requires Claude Code v2.1.193 or later.
            '';
          };
        };
      };
      default = { };
      description = ''
        Auto-mode classifier configuration. Lands at top-level
        `autoMode` in settings.json (NOT under `permissions`). See
        https://code.claude.com/docs/en/auto-mode-config.

        List sub-fields exactly equal to `[ "$defaults" ]` are omitted from
        the generated settings.json (semantically a no-op) to keep the
        file minimal.

        Claude Code reads `autoMode` from user settings
        (`~/.claude/settings.json`), the `--settings` flag, and managed
        settings only — never from a repo's `.claude/settings.json`. This
        module writes user settings, so these values take effect.
      '';
    };

    # `settings` is declared in `./options-settings.nix` with structured
    # sub-options (alwaysThinkingEnabled, cleanupPeriodDays, permissions,
    # env, sandbox, …) AND a freeform attrs type so callers can pass arbitrary
    # keys. We don't re-declare it here.
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (cfg.package != null) [ cfg.package ];

    # Export CLAUDE_CONFIG_DIR only when configDir departs from upstream's own
    # default — at the default this must set nothing, so a caller who never
    # touches configDir sees byte-identical activation output to before this
    # option existed. See options-runtime.nix for the full rationale.
    home.sessionVariables = lib.mkIf (cfg.configDir != ".claude" && cfg.exportConfigDirEnv) {
      CLAUDE_CONFIG_DIR = cfg.configDirAbs;
    };

    # `~/.claude/settings.json` is written by the activation merge in
    # `./settings.nix` (`claudeSettingsMerge`), not by `home.file`. The
    # activation path produces the full settings shape (including
    # `enabledPlugins`, `extraKnownMarketplaces`, and a correct
    # `permissions.defaultMode` value) AND yields a real writable file
    # rather than a symlink — required so Claude Code's runtime mutations
    # to the file are not blocked. Keeping a `home.file` install here
    # caused `linkGeneration` to overwrite the merged result with a
    # symlink to a smaller, inconsistent render (missing
    # `enabledPlugins`, and `permissions.defaultMode = null`).
  };
}
