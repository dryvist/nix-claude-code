{ lib }:
let
  parseMarketplace = import ./parse-marketplace.nix { inherit lib; };
  parsePlugin = import ./parse-plugin.nix { inherit lib; };
  discoverSkills = import ./discover-skills.nix { inherit lib; };
  discoverCommands = import ./discover-commands.nix { inherit lib; };
  discoverAgents = import ./discover-agents.nix { inherit lib; };
  discoverHooks = import ./discover-hooks.nix { inherit lib; };
  toSettingsJson = import ./to-settings-json.nix { inherit lib; };
  permissions = import ./permissions.nix { inherit lib; };
  mkDefaultPermissions = import ./mk-default-permissions.nix { inherit lib; };
  claudeRegistry = import ./claude-registry.nix { inherit lib; };
in
{
  inherit
    parseMarketplace
    parsePlugin
    discoverSkills
    discoverCommands
    discoverAgents
    discoverHooks
    toSettingsJson
    permissions
    mkDefaultPermissions
    claudeRegistry
    ;

  wrapCommandsAsSkills = { pkgs }: import ./wrap-commands-as-skills.nix { inherit lib pkgs; };

  schemaVersion = 1;
}
