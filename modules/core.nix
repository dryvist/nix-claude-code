{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude;

  ncc = import ../lib { inherit lib; };

  # `programs.claude.permissions` is the structured input that
  # `lib.toSettingsJson` consumes. Default to `mkDefaultPermissions`
  # (the full vendored Claude permission set from
  # `data/permissions/*.nix`) so callers get a working, principle-of-
  # least-surprise configuration out of the box. Set to `false` to opt
  # out entirely.
  defaultPermissions = ncc.mkDefaultPermissions { tool = "claude"; };

  # `permissions` accepts either an attrset (use it) or `false` (skip).
  # Use `lib.isAttrs` to discriminate — `!attrset` is a type error.
  effectivePermissions = if lib.isAttrs cfg.permissions then cfg.permissions else null;

  builtSettings = ncc.toSettingsJson {
    permissions = effectivePermissions;
    inherit (cfg) defaultMode autoMode;
    extraSettings = cfg.settings;
  };
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
      # Either an attrset (the structured input from `mkDefaultPermissions`
      # — or a user-supplied override) or `false` to skip writing
      # permissions to settings.json entirely.
      type = lib.types.either lib.types.attrs (lib.types.enum [ false ]);
      default = defaultPermissions;
      defaultText = lib.literalExpression ''lib.mkDefaultPermissions { tool = "claude"; }'';
      description = ''
        Permission lists merged into `~/.claude/settings.json`. The default
        is the full vendored Claude permission set
        (`lib.mkDefaultPermissions { tool = "claude"; }`). Set to `false`
        to omit the `permissions` block entirely; pass an attrset to
        override.
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
        `permissions.defaultMode` in settings.json.

        "auto" is the recommended default — Claude classifies actions
        against the curated deny/ask lists and auto-approves anything not
        in them. Equivalent to running `claude --permission-mode auto`.

        "bypassPermissions" (also reachable via the
        `--dangerously-skip-permissions` CLI flag) skips ALL deny/ask
        checks except credential-read protection. Reserve for trusted
        automation where the deny list is known too aggressive.
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
        };
      };
      default = { };
      description = ''
        Auto-mode classifier configuration. Lands at top-level
        `autoMode` in settings.json (NOT under `permissions`). See
        https://code.claude.com/docs/en/auto-mode-config.

        Sub-fields exactly equal to `[ "$defaults" ]` are omitted from
        the generated settings.json (semantically a no-op) to keep the
        file minimal.
      '';
    };

    # `settings` is declared in `./options-settings.nix` with structured
    # sub-options (alwaysThinkingEnabled, cleanupPeriodDays, permissions,
    # env, sandbox, …) AND a freeform attrs type so callers can pass arbitrary
    # keys. We don't re-declare it here.
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (cfg.package != null) [ cfg.package ];

    # Render the final settings.json into the user's home directory.
    # `home.file` is the canonical home-manager mechanism for managed
    # config files; the file is read-only in the home-manager generation
    # but symlinked at activation so the user's standard tools see it.
    home.file.".claude/settings.json".source =
      (pkgs.formats.json { }).generate "claude-settings.json"
        builtSettings;
  };
}
