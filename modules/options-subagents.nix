# Claude Code subagent model pinning — option declarations.
#
# Imported by the `settings` submodule in `options-settings.nix` (kept in
# its own file for the same per-file size limit reason the curated catalogs
# were split out). These are repo-opinion defaults, not settings.json keys:
# `./settings.nix` renders them into the settings `env` block as
# `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, and
# `CLAUDE_CODE_FORK_SUBAGENT`, and `./settings-assertions.nix` holds the
# rendered values to the defaults below.
# See: https://code.claude.com/docs/en/sub-agents ("Run every subagent on
# one model", "Turn fork mode on or off"); requires Claude Code v2.1.257+.
{ lib, ... }:
{
  options = {
    subagentModel = lib.mkOption {
      type = lib.types.str;
      default = "haiku";
      example = "sonnet";
      description = ''
        Model for every subagent, teammate, and workflow agent. With
        `forceSubagentModel` (the default) the `model` field in agent
        definitions is ignored and Claude cannot pass a model when it
        starts a subagent. Requires Claude Code v2.1.257 or later.

        Defaults to "haiku" so no session this module configures can run
        a subagent on Fable — including a Fable main session, whose
        subagents would otherwise inherit Fable. Setting
        `env.CLAUDE_CODE_SUBAGENT_MODEL` directly overrides this option
        per key (a consumer may point it at a local router model name).
      '';
    };

    forceSubagentModel = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Apply `subagentModel` to every subagent, teammate, and workflow
        agent, instead of only agents that declare no `model` of their
        own. Renders `CLAUDE_CODE_SUBAGENT_MODEL_FORCE = "1"`.
      '';
    };

    forkSubagents = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow Claude to start forks, which inherit the main session's
        model — on a Fable main session that would mean Fable forks. The
        default renders `CLAUDE_CODE_FORK_SUBAGENT = "0"` (forks off).
      '';
    };
  };
}
