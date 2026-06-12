# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with a permanent pre-1.0 cadence — see `release-please-config.json`.

## [0.1.15](https://github.com/dryvist/nix-claude-code/compare/v0.1.14...v0.1.15) (2026-06-12)


### Features

* **permissions:** adopt source-of-truth role + add curated survivors ([#56](https://github.com/dryvist/nix-claude-code/issues/56)) ([5c514e7](https://github.com/dryvist/nix-claude-code/commit/5c514e703180b8326ec1c9b3489cbd6b4a3bbfe4))

## [0.1.14](https://github.com/dryvist/nix-claude-code/compare/v0.1.13...v0.1.14) (2026-06-12)


### Bug Fixes

* **ci:** repoint shared osv-scan workflow to dryvist hub ([#57](https://github.com/dryvist/nix-claude-code/issues/57)) ([c86e169](https://github.com/dryvist/nix-claude-code/commit/c86e1694d30d0cd7d181ceae5e026bb7c61ca703))

## [0.1.13](https://github.com/dryvist/nix-claude-code/compare/v0.1.12...v0.1.13) (2026-06-11)


### Bug Fixes

* **permissions:** auto-allow simple rm, ask for recursive/forced deletes ([#53](https://github.com/dryvist/nix-claude-code/issues/53)) ([217095d](https://github.com/dryvist/nix-claude-code/commit/217095d615537d12795461feccae67c058a2ab8b))

## [0.1.12](https://github.com/dryvist/nix-claude-code/compare/v0.1.11...v0.1.12) (2026-06-10)


### Features

* **permissions:** true-up vendored data to current ai-assistant-instructions JSON ([#50](https://github.com/dryvist/nix-claude-code/issues/50)) ([3441c86](https://github.com/dryvist/nix-claude-code/commit/3441c8651f124bef8b3328e1c8338475076310b1))


### Bug Fixes

* **cleanup:** remove stale-generation symlinks orphan-cleanup misses ([#49](https://github.com/dryvist/nix-claude-code/issues/49)) ([c68fe9c](https://github.com/dryvist/nix-claude-code/commit/c68fe9c14fe34d17c97005b03caf364ce1b30939))
* **renovate:** enable the opt-in nix manager so flake.lock is maintained ([#51](https://github.com/dryvist/nix-claude-code/issues/51)) ([77db0fb](https://github.com/dryvist/nix-claude-code/commit/77db0fbdcc8dffda0c52bfee39f14185be6b001d))

## [0.1.11](https://github.com/dryvist/nix-claude-code/compare/v0.1.10...v0.1.11) (2026-06-04)


### Bug Fixes

* **ci:** replace inlined release-please-action@v4 with org thin wrapper ([#47](https://github.com/dryvist/nix-claude-code/issues/47)) ([bea25c4](https://github.com/dryvist/nix-claude-code/commit/bea25c46b74954143290f8d775ffc4badb1eceaf))

## [0.1.10](https://github.com/dryvist/nix-claude-code/compare/v0.1.9...v0.1.10) (2026-06-02)


### Features

* add autoUpdates option for ~/.claude.json ([#45](https://github.com/dryvist/nix-claude-code/issues/45)) ([9d0a82c](https://github.com/dryvist/nix-claude-code/commit/9d0a82c6a0d045b42fa414a25baf9010c95501bb))
* **ci:** dispatch lock-update event to nix-ai on release ([#44](https://github.com/dryvist/nix-claude-code/issues/44)) ([8f12850](https://github.com/dryvist/nix-claude-code/commit/8f12850f51f44da2e43ed59378732c6650551044))

## [0.1.9](https://github.com/dryvist/nix-claude-code/compare/v0.1.8...v0.1.9) (2026-06-02)


### Bug Fixes

* **settings:** restore freeform settings passthrough for statusLine ([#42](https://github.com/dryvist/nix-claude-code/issues/42)) ([e88f6f0](https://github.com/dryvist/nix-claude-code/commit/e88f6f030d4738662bbbbe2af7cb3675fb0f20cb))

## [0.1.8](https://github.com/dryvist/nix-claude-code/compare/v0.1.7...v0.1.8) (2026-05-31)


### Bug Fixes

* **core:** drop home.file install of settings.json (activation-merge wins) ([#39](https://github.com/dryvist/nix-claude-code/issues/39)) ([9475266](https://github.com/dryvist/nix-claude-code/commit/947526673a8fb52ce400bb824f073f532f4fd2f4))
* **settings:** wrap merge-json-settings.sh in writeShellApplication ([#37](https://github.com/dryvist/nix-claude-code/issues/37)) ([628dd6f](https://github.com/dryvist/nix-claude-code/commit/628dd6fac218e65ce32b1adca7eb6605c1510e1a))

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
