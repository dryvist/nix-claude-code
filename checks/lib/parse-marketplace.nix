{ lib }:
let
  parseMarketplace = import ../../lib/parse-marketplace.nix { inherit lib; };
  emptyResult = parseMarketplace ./fixtures/nonexistent;
  validResult = parseMarketplace ./fixtures/marketplace-valid;
  legacyResult = parseMarketplace ./fixtures/marketplace-top-level-description;
in
{
  # Missing-manifest case: caller path doesn't have a .claude-plugin
  # directory at all.

  "test: handles missing manifest gracefully" = {
    expr = emptyResult.name;
    expected = "unknown";
  };

  "test: returns empty plugin list when manifest is absent" = {
    expr = emptyResult.plugins;
    expected = [ ];
  };

  "test: returns empty owner attrset when manifest is absent" = {
    expr = emptyResult.owner;
    expected = { };
  };

  # Valid marketplace fixture: full Anthropic-spec shape with metadata block
  # and two plugins.

  "test: parses marketplace name" = {
    expr = validResult.name;
    expected = "example-marketplace";
  };

  "test: surfaces description from metadata block when top-level is absent" = {
    expr = validResult.description;
    expected = "Example marketplace for parseMarketplace unit tests";
  };

  "test: parses owner object" = {
    expr = validResult.owner;
    expected = {
      name = "Test Org";
      email = "test@example.com";
    };
  };

  "test: parses metadata block" = {
    expr = validResult.metadata.version;
    expected = "1.0.0";
  };

  "test: parses plugin count" = {
    expr = builtins.length validResult.plugins;
    expected = 2;
  };

  "test: preserves plugin entry fields" = {
    expr = (builtins.head validResult.plugins).name;
    expected = "example-plugin";
  };

  "test: preserves plugin tags and keywords" = {
    expr = (builtins.head validResult.plugins).tags;
    expected = [
      "fixture"
      "testing"
    ];
  };

  # Legacy marketplace with top-level description (no metadata block).

  "test: prefers top-level description over metadata when both styles meet" = {
    expr = legacyResult.description;
    expected = "Older-style top-level description (pre-metadata-block)";
  };

  "test: legacy marketplace exposes empty metadata" = {
    expr = legacyResult.metadata;
    expected = { };
  };
}
