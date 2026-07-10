# Curated catalog of documented settings.json keys with no typed home
# elsewhere in this module set. Imported by the `settings` submodule in
# `options-settings.nix`. All default to `null` (omitted from the generated
# settings.json — see `freeformSettings` in `./settings.nix`) so setting one
# is opt-in and leaves Claude's own upstream default untouched until a
# caller overrides it. Exception: `autoCompactThresholdPercent` carries a
# repo-opinion default (see its comment).
# See: https://code.claude.com/docs/en/settings
{ lib, ... }:
{
  options = {
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
  };
}
