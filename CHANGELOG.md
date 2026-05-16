# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with a permanent pre-1.0 cadence — see `release-please-config.json`.

## [0.1.1](https://github.com/JacobPEvans/nix-claude-code/compare/v0.1.0...v0.1.1) (2026-05-16)


### Features

* initial v0.1.0 scaffolding for nix-claude-code ([1dddab4](https://github.com/JacobPEvans/nix-claude-code/commit/1dddab4e4769dadc5a3538fd46f08868aeda791a))

## [0.1.0] - 2026-05-16

Initial scaffolding. Flake skeleton built on flake-parts with treefmt-nix,
git-hooks.nix, release-please, and home-manager. Module stubs for
`homeModules.{default,claude,core,plugins,statusline,hooks,mcp,latest}`,
empty `lib.*` exports, placeholder `data/permissions/` shape, adopter templates,
examples, and CI.

Content migration from `nix-ai` happens in subsequent v0.x.x releases.
