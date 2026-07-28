{ lib }:
# Autonomous-profile render checks.
#
# Asserts the container-image config produced by lib/render-autonomous.nix
# carries the expected posture (bypassPermissions, empty allow/ask, the full
# residual deny list, Remote Control on) and that the render stays lib-only —
# no home-manager module may deploy it onto a host filesystem.
let
  renderAutonomous = args: import ../../lib/render-autonomous.nix ({ inherit lib; } // args);

  residualDeny = [
    "gh repo delete"
    "git push --force"
    "sudo rm"
  ];

  render = renderAutonomous { inherit residualDeny; };
  settings = builtins.fromJSON render.settingsJson;
  claudeJson = builtins.fromJSON render.claudeJson;

  # Guard the lib-only boundary: an autonomous config landing on a host FS
  # would be a bypassPermissions profile with no container around it.
  moduleReferences = builtins.filter (
    f:
    let
      text = builtins.readFile f;
    in
    lib.hasInfix "render-autonomous" text || lib.hasInfix "renderAutonomous" text
  ) (lib.filesystem.listFilesRecursive ../../modules);
in
{
  "test (autonomous): defaultMode is bypassPermissions" = {
    expr = settings.permissions.defaultMode;
    expected = "bypassPermissions";
  };

  "test (autonomous): allow and ask are empty" = {
    expr = settings.permissions.allow ++ settings.permissions.ask;
    expected = [ ];
  };

  "test (autonomous): deny carries one entry per residualDeny command" = {
    expr = builtins.length settings.permissions.deny;
    expected = builtins.length residualDeny;
  };

  "test (autonomous): deny entries use the Bash(<cmd> *) DSL" = {
    expr = settings.permissions.deny;
    expected = [
      "Bash(gh repo delete *)"
      "Bash(git push --force *)"
      "Bash(sudo rm *)"
    ];
  };

  "test (autonomous): settings.json carries the schemastore \\$schema" = {
    expr = settings."$schema";
    expected = "https://json.schemastore.org/claude-code-settings.json";
  };

  "test (autonomous): .claude.json enables Remote Control at startup" = {
    expr = claudeJson.remoteControlAtStartup;
    expected = true;
  };

  "test (autonomous): files map covers both rendered paths" = {
    expr = builtins.attrNames render.files;
    expected = [
      ".claude.json"
      ".claude/settings.json"
    ];
  };

  "test (autonomous): render is lib-only, referenced by no module" = {
    expr = moduleReferences;
    expected = [ ];
  };
}
