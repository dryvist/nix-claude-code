# Claude Code Module — Top-level runtime options
#
# User-facing knobs that change session behaviour: model selection, effort,
# teammate display mode, auto-updates, remote control, trusted project dirs,
# commit attribution, and headless API key helper.
{ lib, config, ... }:
let
  cfg = config.programs.claude;
in
{
  options.programs.claude = {
    # Where Claude Code's user-global config tree lives, relative to $HOME.
    # Mirrors upstream's (undocumented) CLAUDE_CONFIG_DIR env var — see
    # https://github.com/anthropics/claude-code/issues/3833. Every path this
    # module writes (settings.json, hooks/, commands/, agents/, skills/,
    # rules/, plugins/, the statusline script) is anchored here instead of a
    # hardcoded ".claude", and — unless `exportConfigDirEnv` is turned off —
    # `CLAUDE_CONFIG_DIR` is exported to match, so the `claude` binary reads
    # from the same place Nix writes to.
    #
    # Relative to home rather than absolute: `home.file` keys must be
    # home-relative, so an absolute value would work for the activation-time
    # writes but silently fail to relocate the symlinked components.
    #
    # Two things this does NOT cover, because CLAUDE_CONFIG_DIR itself
    # doesn't: per-project `.claude/settings.local.json` files next to each
    # repo are unaffected, and `~/.claude.json` (the separate runtime-mutable
    # global file `claude-json.nix` manages) only moves under `configDir`
    # when `configDir` is non-default — at the default it stays a sibling of
    # `~/.claude` at `$HOME/.claude.json`, matching upstream's own default.
    configDir = lib.mkOption {
      type = lib.types.str;
      default = ".claude";
      example = ".config/claude";
      description = ''
        Path, relative to `$HOME`, where this module installs Claude Code's
        user-global config tree. Defaults to `.claude` (upstream's own
        default location), so leaving this unset changes nothing.
      '';
    };

    exportConfigDirEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Export `CLAUDE_CONFIG_DIR` (via `home.sessionVariables`) whenever
        `configDir` is set to something other than the default `.claude`.
        Nothing is exported at the default, regardless of this setting.

        Disable this if you export `CLAUDE_CONFIG_DIR` yourself through some
        other mechanism (a login-shell script this module doesn't control,
        for instance) and don't want a second, redundant definition.
      '';
    };

    configDirAbs = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      default = "${config.home.homeDirectory}/${cfg.configDir}";
      description = "Resolved absolute path of `configDir`. Internal — every module that needs an absolute path reads this instead of re-deriving it.";
    };

    # API Key Helper (for headless authentication)
    # Requires ~/.config/bws/.env with Bitwarden/Claude API key env vars.
    # bws_helper.py performs minimal validation — see it for required vars.
    apiKeyHelper = {
      enable = lib.mkEnableOption "API key helper for headless Claude authentication";

      scriptPath = lib.mkOption {
        type = lib.types.str;
        default = ".local/bin/claude-api-key-helper";
        description = "Path (relative to home) where the API key helper script is installed";
      };

      bwsPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        defaultText = lib.literalExpression "null";
        example = lib.literalExpression "pkgs.bws";
        description = ''
          Package providing the `bws` executable the helper shells out to,
          added to the wrapper's runtime path.

          Null by default, which resolves `bws` from the caller's own path
          instead: nixpkgs builds it from a Rust source tree that takes
          several minutes on every cold build, and a consumer that installs
          the vendored official binary system-wide should not pay for that
          twice. The helper reports a clear "bws command not found" error
          when nothing provides it, so an absent executable fails loudly
          rather than silently.

          Set it to a package to make the wrapper self-contained.
        '';
      };
    };

    # Agent teams: coordinate multiple Claude Code instances
    # See: https://code.claude.com/docs/en/agent-teams
    teammateMode = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "in-process"
        "tmux"
      ];
      default = "auto";
      description = ''
        Display mode for agent team teammates.
        - "auto": split panes if already in tmux, in-process otherwise
        - "in-process": all teammates in main terminal (Shift+Up/Down to navigate)
        - "tmux": force split-pane mode (requires tmux)
      '';
    };

    # Auto-update channel for Claude Code binary
    autoUpdatesChannel = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "latest"
      ];
      default = "latest";
      description = ''
        Release channel for Claude Code binary updates.
        - "latest": newest releases immediately (default upstream)
        - "stable": ~1 week delay, fewer regressions
      '';
    };

    # In-app auto-updater toggle for the Claude Code binary.
    # Stored in ~/.claude.json (global config) via home.activation.
    autoUpdates = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Enable Claude Code's built-in auto-updater (writes ~/.claude.json).
        Pairs with autoUpdatesChannel to pick the release channel.
        null = leave unmanaged (Claude Code default is true).
      '';
    };

    # Show turn duration in UI
    showTurnDuration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show how long each turn takes in the Claude Code UI";
    };

    # Remote Control auto-start (Feb 2026 feature)
    # Stored in ~/.claude.json (global config) via home.activation.
    # See: https://code.claude.com/docs/en/remote-control
    remoteControlAtStartup = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Enable Remote Control for all sessions automatically.
        null = leave unmanaged (Claude Code default is false).
      '';
    };

    # Trusted project directories for CLAUDE.md external import approval.
    # Stored in ~/.claude.json under projects.<path> at activation time.
    trustedProjectDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Base directories containing git repos (worktree layout).
        At activation time, discovers all subdirectories and generates
        trust entries (hasClaudeMdExternalIncludesApproved, hasTrustDialogAccepted)
        for each "$baseDir/$repo/main" path in ~/.claude.json.
      '';
      example = [ "~/git" ];
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Override the default model. Accepts aliases ("opus", "sonnet", "haiku")
        or full names. null = account-tier default (opus on Max/Team Premium/
        Enterprise-PAYG/API; sonnet on Pro/Team Standard).
        See: https://code.claude.com/docs/en/model-config
      '';
    };

    effortLevel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "low"
          "medium"
          "high"
          "xhigh"
        ]
      );
      default = null;
      description = ''
        Adaptive reasoning effort for Opus and Sonnet. ("max" is session-only
        and not accepted here.)
        - null: Use upstream default (varies by model; see /effort docs)
        - "high": Recommended. Balances token spend and intelligence
        - "xhigh": Deeper reasoning at higher token spend; heavier on opus
        - "medium": Reduced token usage; trades off some intelligence
        - "low": Minimal reasoning, fastest and cheapest
        Override per-session via /effort command.
      '';
    };

    outputStyle = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Output style adjusting Claude's system prompt (e.g.
        "concise", "explanatory", "learning", "proactive", "default",
        or a custom output style name). null = upstream default (unset).
        See: https://code.claude.com/docs/en/output-styles
      '';
      example = "concise";
    };

    attribution = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Commit/PR attribution settings, emitted verbatim into settings.json.
        Claude Code's schema (https://json.schemastore.org/claude-code-settings.json)
        defines only `commit` and `pr` here, both free-form trailer strings
        (e.g. `commit` uses the Linux kernel-style `Assisted-by` format); an
        empty string hides that attribution. Unknown keys are rejected by the
        schema, so this is `attrsOf str`, not a boolean-toggle map.
      '';
    };

    # Post-activation settings.json schema check. Off by default: it shells
    # out to `nix shell nixpkgs#check-jsonschema` and fetches `settings.schemaUrl`
    # over the network, so enabling it trades a bit of activation time/network
    # dependency for early warning on schema drift. Never blocks activation —
    # see modules/scripts/validate-settings.sh.
    validateSettings.enable = lib.mkEnableOption ''
      warn-only JSON Schema validation of the deployed settings.json against
      `programs.claude.settings.schemaUrl` after each activation
    '';
  };

  # `configDir` is documented as a $HOME-relative path and is interpolated
  # raw into `home.file` keys, activation-time absolute paths, and the
  # symlink-cleanup globs. Reject values that break that contract — an
  # empty string, an absolute path, or a `.`/`..` component — at evaluation
  # time, rather than letting them silently redirect writes or cleanup.
  config.assertions =
    let
      parts = lib.splitString "/" cfg.configDir;
    in
    [
      {
        assertion = cfg.configDir != "" && !(lib.hasPrefix "/" cfg.configDir);
        message = ''
          programs.claude.configDir must be a non-empty path relative to $HOME,
          not an absolute path. Got: "${cfg.configDir}". `home.file` keys are
          home-relative, so an absolute value would silently fail to relocate
          the symlinked components (hooks, commands, agents, skills, rules,
          plugin marketplaces, the statusline script).
        '';
      }
      {
        assertion = !(lib.any (p: p == "" || p == "." || p == "..") parts);
        message = ''
          programs.claude.configDir must not contain empty, "." or ".." path
          components. Got: "${cfg.configDir}".
        '';
      }
      {
        # orphan-cleanup.nix interpolates this value into MARKETPLACES_GLOB,
        # an intentionally-unquoted `case` pattern that decides which of the
        # module's own directories cleanup-conflicting-symlinks.sh will
        # `rm -rf`. A glob metacharacter here would widen that pattern rather
        # than name a directory, so reject them at evaluation time instead of
        # letting one reach a deletion decision.
        assertion =
          !(lib.any (c: lib.hasInfix c cfg.configDir) [
            "*"
            "?"
            "["
            "]"
          ]);
        message = ''
          programs.claude.configDir must not contain the glob metacharacters
          *, ?, [ or ]. Got: "${cfg.configDir}". The value is interpolated
          into the shell `case` pattern that selects directories for removal
          during activation cleanup, where a metacharacter would broaden the
          match instead of naming a path.
        '';
      }
    ];
}
