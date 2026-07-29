_:
# The ASK tier is intentionally empty and must stay that way.
#
# An `ask` entry stops the agent mid-task and waits for a human. When no
# human is present — a scheduled run, a CI job, a headless container, an
# overnight session — that wait never ends: the run stalls until timeout
# and the session goal is abandoned. A prompt nobody can answer is not a
# safety control; it is an outage.
#
# So every command is classified into exactly two tiers:
#
#   deny  — potentially catastrophic: real money, or permanent destruction
#           of a resource that cannot be rebuilt or restored. See deny.nix.
#   allow — everything else, including destructive-but-reversible work.
#           Intent-level judgment is handled by Claude Code's auto-mode
#           classifier and by the PreToolUse guard hooks (git-guards,
#           script-guards, content-guards), which evaluate the *situation*
#           rather than pattern-matching a command prefix.
#
# There is no third tier. If a command is dangerous enough to warrant a
# prompt it belongs in deny.nix; if it is not, it belongs in allow.nix.
#
# The file is kept (rather than deleted) so the empty list stays explicit
# and the renderers in lib/ keep a stable shape across every downstream CLI
# (Claude Code, Codex, Antigravity/agy, opencode, qwen).
#
# Enforced by checks/lib/permissions.nix: "ask.commands is empty".
{
  commands = [ ];
}
