# Claude Code Module — Top-level runtime options
#
# User-facing knobs that change session behaviour: model selection, effort,
# teammate display mode, auto-updates, remote control, trusted project dirs,
# commit attribution, and headless API key helper.
{ lib, ... }:
{
  options.programs.claude = {
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
}
