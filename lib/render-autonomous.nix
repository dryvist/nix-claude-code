# Autonomous-profile render (Claude Code only)
#
# PURE function — no pkgs, no home-manager config. Produces the config file
# contents baked into agent container images (dryvist/nix-agent-sandbox).
# Deliberately NOT a home-manager module: there must be no code path that
# renders this onto a host filesystem. Safety in this profile comes from the
# container boundary, scoped credentials, and default-deny egress — never from
# permission prompts, since there is no human to answer one.
#
# Exposed only via `flake.lib.renderAutonomous`. checks/lib/render-autonomous.nix
# asserts nothing under modules/ references it.
#
# SINGLE-LIST INHERITANCE: the deny output derives from the caller's one
# residualDeny list, rendered through `to-settings-json.nix` — the same
# formatter the interactive home-manager modules use.
{
  lib,
  homeDir ? "/home/agent",
  # Home-relative config dir, mirroring `programs.claude.configDir` for API
  # consistency with `claude-registry.nix`. Default matches upstream's own
  # default, so a caller that doesn't pass this keeps today's paths
  # unchanged. This profile is image-only (see module header) and has no
  # env-var story of its own — an image builder that customizes this is
  # responsible for also baking CLAUDE_CONFIG_DIR into the image itself.
  configDir ? ".claude",
  residualDeny,
}:

let
  toSettingsJson = import ./to-settings-json.nix { inherit lib; };

  # ~/.claude/settings.json inside the image. Launched as
  # `claude -p --bare --dangerously-skip-permissions`. Claude Code enforces
  # permissions.deny even under bypassPermissions, so the residual deny list
  # is real protection here, not decoration.
  settingsJson = builtins.toJSON (toSettingsJson {
    permissions = {
      allow = [ ];
      ask = [ ];
      deny = residualDeny;
    };
    defaultMode = "bypassPermissions";
  });

  # ~/.claude.json — the runtime-mutable global config, not settings.json
  # (see modules/claude-json.nix). Headless autonomous sessions register with
  # Remote Control at startup so a human can observe and steer them.
  claudeJson = builtins.toJSON {
    remoteControlAtStartup = true;
  };
  # .claude.json mirrors the same special case documented in
  # modules/claude-json.nix: a sibling of the config dir at the default, but
  # nested inside it once configDir is customized (observed upstream
  # behavior, undocumented — see
  # https://github.com/anthropics/claude-code/issues/3833).
  claudeJsonPath = if configDir == ".claude" then ".claude.json" else "${configDir}/.claude.json";
in
{
  inherit
    homeDir
    configDir
    residualDeny
    settingsJson
    claudeJson
    ;

  # Home-relative path -> contents, ready for an image builder to bake under
  # ${homeDir}. One attrset so image builds cannot forget a file.
  files = {
    "${configDir}/settings.json" = settingsJson;
    "${claudeJsonPath}" = claudeJson;
  };
}
