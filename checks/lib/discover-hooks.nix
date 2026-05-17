{ lib }:
let
  discoverHooks = import ../../lib/discover-hooks.nix { inherit lib; };
  pluginFixture = ./fixtures/plugin-with-components;
in
{
  "test (hooks): returns empty attrset when hooks.json is absent" = {
    expr = discoverHooks ./fixtures/marketplace-valid;
    expected = { };
  };

  "test (hooks): parses Anthropic-spec hooks.json shape" = {
    expr = builtins.attrNames (discoverHooks pluginFixture).hooks;
    expected = [ "PostToolUse" ];
  };

  "test (hooks): preserves matcher and command fields" = {
    expr =
      let
        firstHook = builtins.head (discoverHooks pluginFixture).hooks.PostToolUse;
      in
      {
        inherit (firstHook) matcher;
        commandSuffix = lib.hasSuffix "post-edit.sh" (builtins.head firstHook.hooks).command;
      };
    expected = {
      matcher = "Edit";
      commandSuffix = true;
    };
  };
}
