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
in
{
  inherit
    homeDir
    residualDeny
    settingsJson
    claudeJson
    ;

  # Home-relative path -> contents, ready for an image builder to bake under
  # ${homeDir}. One attrset so image builds cannot forget a file.
  files = {
    ".claude/settings.json" = settingsJson;
    ".claude.json" = claudeJson;
  };
}
