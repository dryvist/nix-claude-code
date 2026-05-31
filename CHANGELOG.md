# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with a permanent pre-1.0 cadence — see `release-please-config.json`.

## [0.1.7](https://github.com/dryvist/nix-claude-code/compare/v0.1.6...v0.1.7) (2026-05-31)


### Bug Fixes

* **ci:** drop FlakeHub cache, adopt shared nix-validate template ([#33](https://github.com/dryvist/nix-claude-code/issues/33)) ([02af7e3](https://github.com/dryvist/nix-claude-code/commit/02af7e3640397532951e3121071af4ceef957975))

## [0.1.6](https://github.com/dryvist/nix-claude-code/compare/v0.1.5...v0.1.6) (2026-05-31)


### Features

* **catalog:** promote jacobpevans-cc-plugins + karpathy-skills upstream ([#29](https://github.com/dryvist/nix-claude-code/issues/29)) ([9fe7a2e](https://github.com/dryvist/nix-claude-code/commit/9fe7a2e86265a96d69f97e6514a5a3e012743b9c))


### Bug Fixes

* **devshell:** warn before pre-commit installer hits core.hooksPath block ([#31](https://github.com/dryvist/nix-claude-code/issues/31)) ([9fc82a2](https://github.com/dryvist/nix-claude-code/commit/9fc82a2c31f2244838eaf3d1fe3dbe43673fb7b2))
* **settings:** render autoMode in ~/.claude/settings.json ([#28](https://github.com/dryvist/nix-claude-code/issues/28)) ([60c0488](https://github.com/dryvist/nix-claude-code/commit/60c0488a90acd8c9183f681117ba5ea2cade8213))

## [0.1.5](https://github.com/dryvist/nix-claude-code/compare/v0.1.4...v0.1.5) (2026-05-30)

### Features

- **core:** defaultMode + autoMode options; adopt nix-devenv dev-hygiene ([#21](https://github.com/dryvist/nix-claude-code/issues/21)) ([6d2c1bc](https://github.com/dryvist/nix-claude-code/commit/6d2c1bc86797dff29a6db84090a99769a7a7ba5f))
- **modules:** port programs.claude.\* module from nix-ai ([#26](https://github.com/dryvist/nix-claude-code/issues/26)) ([5276fb5](https://github.com/dryvist/nix-claude-code/commit/5276fb566c8cf8078f808d8dbd5923bcd0e00c1a))

### Bug Fixes

- **ci:** retarget reusable-workflow uses: refs to current org homes ([#25](https://github.com/dryvist/nix-claude-code/issues/25)) ([8c42ead](https://github.com/dryvist/nix-claude-code/commit/8c42eadc4b5b7e2c3013db81a883f266816dcaba))

## [0.1.4](https://github.com/dryvist/nix-claude-code/compare/v0.1.3...v0.1.4) (2026-05-17)

### Features

- **core:** write settings.json from permissions + statusline + extras ([#16](https://github.com/dryvist/nix-claude-code/issues/16)) ([bcf2729](https://github.com/dryvist/nix-claude-code/commit/bcf272926e521e187923176c097ba14812909632))
- **statusline:** implement powerline, ccstatusline, daniel3303 themes ([#14](https://github.com/dryvist/nix-claude-code/issues/14)) ([cadb13b](https://github.com/dryvist/nix-claude-code/commit/cadb13be440c11ade7da4d9305f1ae2353b7bb19))

## [0.1.3](https://github.com/dryvist/nix-claude-code/compare/v0.1.2...v0.1.3) (2026-05-17)

### Features

- **lib:** implement discoverSkills/Commands/Agents/Hooks per Anthropic spec ([#11](https://github.com/dryvist/nix-claude-code/issues/11)) ([33d9538](https://github.com/dryvist/nix-claude-code/commit/33d9538bb5599013175961020dc2480992b9df5d))
- **lib:** implement toSettingsJson and wrapCommandsAsSkills ([#13](https://github.com/dryvist/nix-claude-code/issues/13)) ([3b18dd0](https://github.com/dryvist/nix-claude-code/commit/3b18dd0b9383d98e37e04df14879617bffa0f406))

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
