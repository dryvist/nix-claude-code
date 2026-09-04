# Curated catalog of settings.json policy keys — the switches that decide what
# Claude Code is permitted to do, rather than how it looks or which model it
# picks. Imported by the `settings` submodule in `options-settings.nix`,
# alongside `options-settings-catalog.nix`; kept separate because that file is
# near the per-file size limit and these keys form their own concern.
#
# All default to `null`, so they are omitted from the generated settings.json
# (see `freeformSettings` in `./settings.nix`) and Claude's own upstream default
# stands until a caller overrides one. Declaring them typed rather than leaving
# them to freeform passthrough gives them evaluation-time validation, which is
# what a trust boundary warrants.
# See: https://code.claude.com/docs/en/settings
{ lib, ... }:
{
  options = {
    # --- Hook execution -------------------------------------------------

    disableAllHooks = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Disable execution of every configured hook, including the statusLine
        command. null = upstream default (`false`).
      '';
    };

    allowedHttpHookUrls = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        URL patterns an HTTP hook may target. A hook whose URL is not matched
        is refused. null = upstream default.
      '';
      example = [ "https://hooks.example.com/*" ];
    };

    httpHookAllowedEnvVars = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Environment variables an HTTP hook may interpolate into its request
        headers. Anything not listed is unavailable to the hook, so a secret
        in the environment is not reachable by default. null = upstream default.
      '';
    };

    # --- Skill and command execution ------------------------------------

    disableSkillShellExecution = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Block inline shell substitution inside skills and slash commands.
        null = upstream default (`false`).
      '';
    };

    disableBundledSkills = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Omit the skills and workflows bundled with Claude Code, leaving only
        those this module set installs. null = upstream default (`false`).
      '';
    };

    claudeMdExcludes = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Glob patterns for CLAUDE.md files that must not be loaded. Complements
        the `rules` option, which controls what this module set delivers rather
        than what Claude discovers on its own. null = upstream default.
      '';
      example = [ "**/vendor/**/CLAUDE.md" ];
    };

    # --- MCP server admission (data only; runtimes live in the consumer) --

    enabledMcpjsonServers = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Servers from a project's `.mcp.json` to approve without prompting.
        null = upstream default (prompt for each).
      '';
    };

    disabledMcpjsonServers = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Servers from a project's `.mcp.json` to reject outright.
        null = upstream default.
      '';
    };

    allowedMcpServers = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Allowlist of MCP servers that may be used at all. null = upstream
        default (no allowlist).
      '';
    };

    deniedMcpServers = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Denylist of MCP servers that may never be used. null = upstream
        default (no denylist).
      '';
    };

    # --- Remote Control and version floor -------------------------------

    disableRemoteControl = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Disable Remote Control outright, regardless of
        `remoteControlAtStartup`. null = upstream default (`false`).
      '';
    };

    minimumVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Refuse to run below this Claude Code version. A floor, not a pin: it
        prevents dropping below a known-good release, and does not stop
        upgrades. null = upstream default (no floor).
      '';
      example = "2.1.251";
    };
  };
}
