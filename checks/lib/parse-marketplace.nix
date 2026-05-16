{ lib }:
let
  parseMarketplace = import ../../lib/parse-marketplace.nix { inherit lib; };
  emptyResult = parseMarketplace ./fixtures/nonexistent;
in
{
  "test: handles missing manifest gracefully" = {
    expr = emptyResult.name;
    expected = "unknown";
  };
  "test: returns empty plugin list when manifest is absent" = {
    expr = emptyResult.plugins;
    expected = [ ];
  };
}
