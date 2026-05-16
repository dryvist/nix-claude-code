# Compatibility

## Supported versions

| Component       | Tested / required                                                  |
| --------------- | ------------------------------------------------------------------ |
| Claude Code     | latest stable (Anthropic upstreams float; no version pin)          |
| nixpkgs         | `nixos-25.11`                                                      |
| home-manager    | `release-25.11`                                                    |
| `flake-parts`   | latest                                                             |
| `treefmt-nix`   | latest                                                             |
| `git-hooks.nix` | latest                                                             |
| Platforms       | `aarch64-darwin`, `x86_64-darwin`, `aarch64-linux`, `x86_64-linux` |

## Anthropic plugin spec

`nix-claude-code` follows Anthropic's official Claude Code plugin specification verbatim:

| Concept             | Location / file                                                |
| ------------------- | -------------------------------------------------------------- |
| Plugin manifest     | `.claude-plugin/plugin.json`                                   |
| Marketplace catalog | `.claude-plugin/marketplace.json` (`$schema` on Anthropic CDN) |
| Skills              | `skills/<name>/SKILL.md`                                       |
| Commands            | `commands/<name>.md` (legacy, prefer skills)                   |
| Agents              | `agents/<name>.md`                                             |
| Hooks               | `hooks/hooks.json`                                             |
| MCP servers         | `.mcp.json`                                                    |
| LSP servers         | `.lsp.json`                                                    |
| Monitors            | `monitors/monitors.json`                                       |
| Default settings    | `settings.json` (plugin root)                                  |
| Plugin executables  | `bin/`                                                         |

Source: [code.claude.com/docs/en/plugins-reference](https://code.claude.com/docs/en/plugins-reference).

## Plugin source types

Per `marketplace.json` schema:

- `local-path` — local directory reference
- `git-subdir` — subdirectory of a git repo (with `path` + `ref`/`sha`)
- `url` — full git repo (with `sha`)
- `github` — GitHub shorthand (with `repo` + `commit`/`sha`)

## Plugin categories

Per Anthropic's official taxonomy: `development`, `security`, `productivity`, `design`,
`database`, `deployment`, `monitoring`, `location`, `learning`.

## Versioning

Pre-v1 forever (see [`release-please-config.json`](../release-please-config.json)).
`feat:` / `fix:` → patch bump; `feat!:` / `fix!:` → minor bump; major never auto-bumps.
