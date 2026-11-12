# Config directory (`configDir`)

`programs.claude.configDir` anchors every file this module writes to a
single `$HOME`-relative path. This page covers the relocation surface;
the option surface itself is in [settings.md](settings.md).

By default this module writes Claude Code's user-global config tree —
`settings.json`, `hooks/`, `commands/`, `agents/`, `skills/`, `rules/`,
`plugins/`, the statusline script — to `~/.claude`, upstream's own default.
Set `programs.claude.configDir` (a path relative to `$HOME`) to move all of
it somewhere else, e.g. to keep `$HOME` XDG-clean:

```nix
programs.claude.configDir = ".config/claude";
```

Every path this module writes is anchored to `configDir`, and
`CLAUDE_CONFIG_DIR` is exported (via `home.sessionVariables`) to match, so
the `claude` binary reads from the same place Nix writes to — set
`programs.claude.exportConfigDirEnv = false` if you export it yourself
through some other mechanism. At the default `.claude`, nothing is exported
and every path is unchanged from before this option existed.

The vendored runtime scripts that can't be Nix-rewritten — the
marketplace-refresh `sessionStart` hook and the `daniel3303` statusline —
read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` themselves, so they follow a
relocated tree too (via the exported env var, or their upstream-default
fallback when it's unset).

`configDir` must be a non-empty path relative to `$HOME` with no `.` or
`..` components; an absolute or empty value fails evaluation rather than
silently misdirecting the activation writes.

Two things this does **not** cover, because upstream's own
`CLAUDE_CONFIG_DIR` doesn't either:

- Per-project `.claude/settings.local.json` files next to each repo are
  unaffected.
- `CLAUDE_CONFIG_DIR` itself is undocumented by Anthropic (see
  [anthropics/claude-code#3833](https://github.com/anthropics/claude-code/issues/3833)).
  Its observed (not officially specified) behavior treats `.claude.json` —
  the separate runtime-mutable global file `modules/claude-json.nix` manages —
  as a special case: a sibling of the config dir at
  `$HOME/.claude.json` when `configDir` is left at its default, but nested
  _inside_ the config dir once `configDir` is customized. This module mirrors
  that.
