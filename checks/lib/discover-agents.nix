{ lib }:
let
  discoverAgents = import ../../lib/discover-agents.nix { inherit lib; };
  pluginFixture = ./fixtures/plugin-with-components;
in
{
  "test (agents): returns empty list when agents/ is absent" = {
    expr = discoverAgents ./fixtures/marketplace-valid;
    expected = [ ];
  };

  "test (agents): discovers all *.md files in agents/" = {
    expr = map (a: a.name) (discoverAgents pluginFixture);
    expected = [ "reviewer" ];
  };

  "test (agents): each entry includes pluginRoot" = {
    expr = (builtins.head (discoverAgents pluginFixture)).pluginRoot;
    expected = pluginFixture;
  };
}
