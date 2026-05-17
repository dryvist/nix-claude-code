# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with a permanent pre-1.0 cadence — see `release-please-config.json`.

## [0.1.3](https://github.com/dryvist/nix-claude-code/compare/v0.1.2...v0.1.3) (2026-05-17)


### Features

* **lib:** implement discoverSkills/Commands/Agents/Hooks per Anthropic spec ([#11](https://github.com/dryvist/nix-claude-code/issues/11)) ([33d9538](https://github.com/dryvist/nix-claude-code/commit/33d9538bb5599013175961020dc2480992b9df5d))
* **lib:** implement toSettingsJson and wrapCommandsAsSkills ([#13](https://github.com/dryvist/nix-claude-code/issues/13)) ([3b18dd0](https://github.com/dryvist/nix-claude-code/commit/3b18dd0b9383d98e37e04df14879617bffa0f406))

## [0.1.2](https://github.com/dryvist/nix-claude-code/compare/v0.1.1...v0.1.2) (2026-05-17)

### Features

- **permissions:** port allow/ask/deny/domains data from ai-assistant-instructions ([#8](https://github.com/dryvist/nix-claude-code/issues/8)) ([1823366](https://github.com/dryvist/nix-claude-code/commit/1823366e979efede352432f230ee751f1a997040))

## [0.1.1](https://github.com/dryvist/nix-claude-code/compare/v0.1.0...v0.1.1) (2026-05-16)

### Features

- initial v0.1.0 scaffolding for nix-claude-code ([1dddab4](https://github.com/dryvist/nix-claude-code/commit/1dddab4e4769dadc5a3538fd46f08868aeda791a))

### Bug Fixes

- **ci:** use correct flake check attribute names ([#2](https://github.com/dryvist/nix-claude-code/issues/2)) ([0ee9c1b](https://github.com/dryvist/nix-claude-code/commit/0ee9c1b2e9d3492cea049200757311d5b02166ff))

## [0.1.0] - 2026-05-16

Initial scaffolding. Flake skeleton built on flake-parts with treefmt-nix,
git-hooks.nix, release-please, and home-manager. Module stubs for
`homeModules.{default,claude,core,plugins,statusline,hooks,mcp,latest}`,
empty `lib.*` exports, placeholder `data/permissions/` shape, adopter templates,
examples, and CI.

Content migration from `nix-ai` happens in subsequent v0.x.x releases.
