# Permission Data (source of truth)

Tool-agnostic permission data. **This directory is the single source of
truth.** Checkpoint 3 is complete: the data was originally vendored from
`ai-assistant-instructions/agentsmd/permissions/` (see the snapshot date and
source rev in each `.nix` header), nix-ai now reads from here, and the
upstream JSON copy has been retired (dryvist/ai-assistant-instructions#680).

Per-category background (what each file holds, which source JSONs fed it)
lives in the header comments of the `.nix` files. This README only carries
the maintainer rules that would otherwise be lost with the JSON tree.

## Format rules

- Entries are bare commands with **no trailing `*` wildcard**. The per-tool
  formatters append it (`"git"` → Claude's `Bash(git *)`). A trailing `*`
  in the data would render an invalid double wildcard (`Bash(git * *)`).
- The generated space-wildcard enforces a word boundary: `Bash(nix *)`
  matches `nix search` but not `nix-env` (a separate binary, listed
  separately).

## Precedence model

Consumers resolve Deny > Ask > Allow — a stricter level always wins,
regardless of pattern specificity. That ordering still holds, so a coarse
allow (`git`, `docker`, `aws`) is safely re-gated by a specific deny
(`aws ec2 terminate-instances`). What changed is that the middle level is
now always empty.

### Two tiers only — there is no ASK

`ask.nix` is permanently empty and CI enforces it. An `ask` entry stops the
agent and waits for a human; in a scheduled run, CI job, container, or
overnight session no human arrives, so the run stalls until timeout and the
session goal is abandoned. A prompt nobody can answer is an outage, not a
control.

Every command is therefore either:

- **deny** — potentially catastrophic: real money, or permanent destruction
  of something that cannot be rebuilt or restored.
- **allow** — everything else, including destructive-but-reversible work.

Situational judgment lives where it can actually reason about context:
Claude Code's auto-mode classifier, and the PreToolUse guard hooks
(`git-guards`, `script-guards`, `content-guards`). Those can weigh a given
command in a given repo on a given branch; a prefix list cannot.

Consumers still resolve Deny > Ask > Allow, so a coarse allow (`git`,
`docker`, `aws`) is safely re-gated by a specific deny
(`aws ec2 terminate-instances`).

Nix-first philosophy: package **install** commands are denied — environments
are defined by Nix, Homebrew, or bun/bunx, and an ad-hoc install mutates
state Nix believes it owns. `npx` and `pnpx` are denied for the same reason;
`bunx` and `uvx` are the sanctioned ad-hoc runners.

## Consumers filter, data does not

This data carries the complete permission set. Profile-specific trimming
belongs in the consumer, via `excludeDenyCategories` / `excludeDenyCommands`.
Never remove entries here to satisfy one consumer.
