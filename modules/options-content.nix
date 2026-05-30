# Claude Code Module — Content discovery options
#
# How Claude Code finds plugins, commands, agents, skills, and rules.
# Supports three sources: marketplace plugins (via flake inputs), Nix store
# components (fromFlakeInputs), and ad-hoc local paths (local).
{ lib, ... }:
let
  inherit (import ./options-types.nix { inherit lib; }) marketplaceModule componentModule;
in
{
  options.programs.claude = {
    plugins = {
      marketplaces = lib.mkOption {
        type = lib.types.attrsOf marketplaceModule;
        default = { };
        description = ''
          Marketplaces (keyed by `name` field from each repo's
          `.claude-plugin/marketplace.json`) that publish plugins for
          Claude Code.
        '';
      };
      enabled = lib.mkOption {
        type = lib.types.attrsOf lib.types.bool;
        default = { };
        description = ''
          Plugins to enable, keyed by `"plugin-name@marketplace-name"`.
        '';
      };
      allowRuntimeInstall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Allow Claude Code to install plugins at runtime (via
          `/plugin install`) in addition to the Nix-managed set.
        '';
      };
    };

    commands = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
      fromLiveRepo = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
      liveRepoCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };

    agents = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
    };

    skills = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
    };

    # Global rules (loaded every session regardless of project)
    rules = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
    };
  };
}
