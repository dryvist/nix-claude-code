{ lib }:
let
  discoverCommands = import ../../lib/discover-commands.nix { inherit lib; };
  pluginFixture = ./fixtures/plugin-with-components;
in
{
  "test (commands): returns empty list when commands/ is absent" = {
    expr = discoverCommands ./fixtures/marketplace-valid;
    expected = [ ];
  };

  "test (commands): discovers all *.md files in commands/" = {
    expr = builtins.length (discoverCommands pluginFixture);
    expected = 2;
  };

  "test (commands): ignores non-.md files" = {
    expr = builtins.any (c: c.name == "not-a-command") (discoverCommands pluginFixture);
    expected = false;
  };

  "test (commands): strips .md suffix from name" = {
    expr = builtins.sort builtins.lessThan (map (c: c.name) (discoverCommands pluginFixture));
    expected = [
      "build"
      "test"
    ];
  };

  "test (commands): each entry includes pluginRoot" = {
    expr = (builtins.head (discoverCommands pluginFixture)).pluginRoot;
    expected = pluginFixture;
  };
}
