# Install method (`install`)

`programs.claude.install` picks how the Claude Code binary gets onto the
machine. It defaults to `"native"` on darwin and `"nix"` elsewhere.

Each mode sets existing options with `lib.mkDefault`. An explicit value for
any of those options still wins.

- **`native`** (darwin default): the binary lives at `~/.local/bin/claude`.
  Anthropic's installer puts it there at home-manager activation, and Claude
  Code updates it afterward. The mode sets `package` to `null`, enables
  `latest`, and sets `autoUpdates` to `true`. On other platforms it installs
  no binary.
- **`brew`**: the binary lives at `/opt/homebrew/bin/claude`, from the cask
  named by `brewCask` (`claude-code@latest`). The mode sets `package` to
  `null` and `settings.env.CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE` to `"1"`,
  so Claude Code upgrades the cask itself. The path assumes the Apple Silicon
  Homebrew prefix. Intel Macs use `/usr/local`.
- **`nix`** (other platforms' default): the binary is `<package>/bin/claude`.
  The mode changes no other option. Setting `package` to `null` in this mode
  fails an assertion.

`binaryPath` and `brewCask` are read-only. They follow from `install`.
