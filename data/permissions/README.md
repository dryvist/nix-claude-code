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
regardless of pattern specificity. The data layers accordingly:

- **Coarse allows**: bare tool names (`git`, `docker`, `aws`) grant whole
  command families for convenience.
- **Specific asks**: dangerous subcommands (`git merge`, `docker exec`)
  re-gate slices of an allowed family.
- **Denies**: as specific as possible to avoid false positives.

Nix-first philosophy: package _install_ commands are denied (use the Nix
dev shell instead); package _runners_ (`npx`, `uvx`, `pipx run`) ask.

## Consumers filter, data does not

This data carries the complete permission set. Profile-specific trimming
belongs in the consumer — e.g. nix-ai's reader excludes the shell and
network deny categories via `excludeDenyFiles`. Never remove entries here
to satisfy one consumer.
