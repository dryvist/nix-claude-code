# Migration from nix-ai

`nix-claude-code` was extracted from [`nix-ai`](https://github.com/JacobPEvans/nix-ai)
following a 4-checkpoint plan. This document tracks the migration state.

## Checkpoint 0 — baseline snapshot

Captured in nix-ai/main:

- `nix build .#checks.aarch64-darwin.claude-module-eval` → snapshot store path
- `nix eval .#lib.ci.claudeSettingsJson --json` → snapshot settings.json (702 lines:
  356 allow rules, 103 deny rules, 94 plugins, 21 marketplaces)
- Discovered skill list from `modules/agent-skills`

These snapshots are the regression oracles for the migration.

## Checkpoint 1 — scaffolding published, content migration

**Status:** scaffolding shipped in v0.1.0 (this release). Content migration in
subsequent v0.x.x releases.

What lands per release:

- Anthropic upstream parsers (`lib.parseMarketplace`, `lib.parsePlugin`)
- Skill / command / agent / hook discovery walkers
- Permission data migrated from `ai-assistant-instructions/agentsmd/permissions/`
- Statusline themes (powerline, ccstatusline, daniel3303)
- Claude settings.json builder

**Gate:** evaluating `homeModules.default` against the same 17 marketplace inputs
must produce a settings.json byte-identical to the nix-ai/main snapshot. CI enforces
this once the content lands.

## Checkpoint 2 — nix-ai adopts in parallel

In `nix-ai`:

1. Add `inputs.nix-claude-code` with `follows` overrides.
2. Add `programs.claude.useExternalModule` option (default `false`).
3. When `true`, swap `modules/default.nix`'s claude import for `inputs.nix-claude-code.homeModules.default`.
4. Refactor `modules/agent-skills/default.nix` to import `inputs.nix-claude-code.lib.discoverSkills`
   and `lib.wrapCommandsAsSkills`.
5. Codex / Gemini modules switch their permission imports to
   `inputs.nix-claude-code.lib.permissions.*`.
6. CI runs both paths, asserts identical output.

## Checkpoint 3 — cutover (done)

1. Flip `useExternalModule` default to `true`.
2. ✅ Done — the `agentsmd/permissions/` JSON tree was removed from
   `ai-assistant-instructions` (dryvist/ai-assistant-instructions#680); all
   tools now source from `nix-claude-code.lib.permissions`.
3. Soak for at least two `nix-ai` releases.

## Checkpoint 3.5 — Claude-only mechanisms upstreamed (in progress)

Beyond the structural checkpoints above, individual Claude-only _mechanisms_
that nix-ai hardcoded are moved upstream as they're identified, each behind
an override-friendly default (see `docs/settings.md`):

- **Settings schema validation** — `nix-ai/modules/scripts/validate-claude-settings.sh`
  → `modules/scripts/validate-settings.sh` + `programs.claude.validateSettings.enable`
  (default `false`; nix-ai flips it on).
- **Universal `additionalDirectories`** (`~/.claude/`, `/tmp/`) — builder-merged
  in `modules/settings.nix` rather than an option default, so nix-ai's
  host-specific entries keep concatenating rather than being replaced.
- **Sensible `env` defaults** (`MCP_TIMEOUT`, `MCP_TOOL_TIMEOUT`,
  `ENABLE_TOOL_SEARCH`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — same
  builder-merge pattern, merged _under_ `programs.claude.settings.env` so a
  per-key override in nix-ai still wins.

**nix-ai follow-up (tracked separately):** once this lands on `nix-claude-code`
main, bump the pin, set `validateSettings.enable = true`, delete
`nix-ai/modules/scripts/validate-claude-settings.sh` and its activation
entry, drop the now-redundant keys from `nix-ai/modules/claude/settings-env.nix`
(keep the OTEL/telemetry block — that stays personal) and the two universal
entries from `nix-ai/modules/claude/settings-paths.nix` (keep the
host-specific ones), then re-run the byte-equivalence check + `darwin-rebuild`.

## Checkpoint 4 — deletion

Hard-delete from `nix-ai`:

- `modules/claude/**`
- `modules/permissions/claude-permissions-*.nix`
- `modules/claude-config.nix`, `modules/claude-latest.nix`, `modules/claude-plugins.nix`
- `modules/claude-statusline-switch.zsh`
- `lib/claude-settings.nix`, `lib/claude-registry.nix`
- `lib/checks/claude.nix`
- The 17 marketplace inputs from `flake.nix`
- `programs.claude.useExternalModule` option

Update `nix-ai/README.md` and `CLAUDE.md` to reflect the split.
