# nix-claude-code - AI Agent Instructions

Declarative Claude Code in Nix — plugins, marketplaces, skills, hooks, MCP, and
permissions as composable home-manager modules. Reproducible on macOS and Linux.

## Critical Constraints

1. **Flakes-only**: Never use `nix-env` or imperative Nix commands.
2. **Module args injection**: All flake inputs reach modules via `_module.args`,
   not function parameters.
3. **Worktrees required**: Run `/refresh-repo` then create a worktree before any work.
4. **No direct main commits**: Always use feature branches.
5. **Anthropic spec compliance**: Plugin and marketplace formats follow the
   [official spec](https://code.claude.com/docs/en/plugins-reference) verbatim;
   no proprietary extensions.

## Validation

**Static** (every change):

```bash
nix flake check    # Formatting, statix, deadnix, lib regression tests
nix fmt            # Fix formatting
```

**Runtime** (changes to plugins, hooks, settings, activations, MCP servers):

```bash
sudo darwin-rebuild switch --flake "$HOME/git/nix-darwin/main" \
  --override-input nix-claude-code "$HOME/git/nix-claude-code/<worktree>"
```

Then verify in a live Claude Code session — static checks validate Nix
evaluation, not runtime behavior. Start a fresh session and confirm the feature
loads without errors before claiming done.

## Architecture

This repo exports home-manager modules consumed by nix-ai (and any other flake
that wants Claude Code as Nix):

- `homeModules.default` / `homeModules.claude` — Full Claude Code stack
- `homeModules.core` — `settings.json` + permissions + the `claude-code` binary
- `homeModules.plugins` — Marketplace + plugin management
- `homeModules.statusline` — Powerline / ccstatusline / daniel3303 themes
- `homeModules.hooks` — Session-output capture + marketplace-refresh hooks
- `homeModules.mcp` — `programs.claude.mcpServers` option (data only)
- `homeModules.latest` — Opt-in auto-installer for the latest Claude Code release
- `flakeModule` — flake-parts wiring
- `lib.*` — Pure functions any AI-agent tool can consume (`parseMarketplace`,
  `discoverSkills`, `mkDefaultPermissions`, etc.)

### Self-contained design

Modules inject their own dependencies via `_module.args`. Consumers only need:

```nix
inputs.nix-claude-code.inputs.nixpkgs.follows = "nixpkgs";
inputs.nix-claude-code.inputs.home-manager.follows = "home-manager";
```

## Separation Guidelines

### What belongs here (nix-claude-code)

- Claude Code itself (the binary, `settings.json`, permission rules)
- Plugin / marketplace / skill / agent / hook discovery and wiring
- Statusline themes
- MCP server _option_ surface — data only; runtime implementations live elsewhere
- Pure lib functions parsing Anthropic plugin-spec data

### What does NOT belong here

- MCP server _implementations_ and runtimes — those live in nix-ai
- Non-Claude AI tools (Gemini, Copilot, Codex) — those live in nix-ai
- Permission rule sources — sourced from `ai-assistant-instructions`

### Package placement

The `nix-package-placement` rule lives in
[ai-assistant-instructions][nix-pkg-placement] and auto-loads via path-scoping
when `.nix` / `flake.*` files are in context.

[nix-pkg-placement]: https://github.com/JacobPEvans/ai-assistant-instructions/blob/main/agentsmd/rules/nix-package-placement.md

## Key Files

- `flake.nix` — Marketplace input pins + flake outputs
- `flake/modules.nix` — Module composition
- `modules/` — home-manager modules
- `lib/` — Pure functions (`parseMarketplace`, `parsePlugin`, `discoverSkills`, etc.)
- `data/permissions/` — Permission rule sources consumed by `lib.mkDefaultPermissions`
- `templates/` — Flake init scaffolds (`minimal`, `flake-parts`)
- `checks/` — nix-unit regression tests for lib functions

## Tooling baseline (inherited from dryvist/.github)

- **Markdown lint:** `markdownlint-cli2` with the canonical
  `.markdownlint-cli2.yaml` synced from
  [`dryvist/.github`](https://github.com/dryvist/.github).
  `MD013 line_length: 160`; no 80-char heading/code restrictions.
  `CHANGELOG.md` is ignored (release-please auto-generated).
  `MD024` strict-by-default everywhere actually linted — never
  disabled across the board.
- **Pre-commit / formatters / zizmor:** centralized via the
  [`nix-devenv`](https://github.com/JacobPEvans/nix-devenv) flake module
  `flakeModules.dev-hygiene`, imported in `flake.nix`. No
  `.pre-commit-config.yaml` in this repo — the module declares treefmt,
  pre-commit hooks (including `gitleaks` and the Nix toolchain
  `nixfmt`/`statix`/`deadnix`), and zizmor policy in Nix. To run locally:
  `nix develop` then `pre-commit run --all-files`.
- **nixpkgs channel:** `nixos-unstable` (with `home-manager/master`) —
  keeps `markdownlint-cli2` at a version that supports `MD060` natively;
  do not work around stale tooling by disabling rules.

Do NOT commit local copies of `.markdownlint-cli2.{jsonc,yaml}` that drift
from the dryvist canonical, and do NOT re-introduce leniency rules to work
around stale tooling. Pre-commit hook definitions belong in `nix-devenv`
(the org's shared module), not in a per-repo `.pre-commit-config.yaml`.

## Related Repos

- [JacobPEvans/nix-ai](https://github.com/JacobPEvans/nix-ai) — multi-tool AI workspace that consumes this flake
- [JacobPEvans/nix-home](https://github.com/JacobPEvans/nix-home) — user dev environment in Nix
- [JacobPEvans/nix-devenv](https://github.com/JacobPEvans/nix-devenv) — reusable dev shells
- [JacobPEvans/ai-assistant-instructions](https://github.com/JacobPEvans/ai-assistant-instructions) —
  agent rules and permission sources
- [JacobPEvans/claude-code-plugins](https://github.com/JacobPEvans/claude-code-plugins) —
  custom marketplace consumed via the `jacobpevans-cc-plugins` input
