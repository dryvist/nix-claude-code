{ lib }:
let
  parsePlugin = import ../../lib/parse-plugin.nix { inherit lib; };
  emptyResult = parsePlugin ./fixtures/nonexistent-plugin;
  fullResult = parsePlugin ./fixtures/plugin-full;
  minimalResult = parsePlugin ./fixtures/plugin-minimal;
in
{
  # Missing-manifest case.

  "test (plugin): handles missing manifest gracefully" = {
    expr = emptyResult.name;
    expected = "unknown";
  };

  "test (plugin): returns null version when manifest is absent" = {
    expr = emptyResult.version;
    expected = null;
  };

  "test (plugin): returns empty keywords when manifest is absent" = {
    expr = emptyResult.keywords;
    expected = [ ];
  };

  # Full fixture exercises every spec field.

  "test (plugin): parses name" = {
    expr = fullResult.name;
    expected = "fully-populated-plugin";
  };

  "test (plugin): parses description" = {
    expr = fullResult.description;
    expected = "Plugin manifest exercising every documented field";
  };

  "test (plugin): parses version" = {
    expr = fullResult.version;
    expected = "1.2.3";
  };

  "test (plugin): parses author object" = {
    expr = fullResult.author.name;
    expected = "Test Author";
  };

  "test (plugin): parses homepage" = {
    expr = fullResult.homepage;
    expected = "https://example.com/fully-populated-plugin";
  };

  "test (plugin): parses repository" = {
    expr = fullResult.repository;
    expected = "https://github.com/example/fully-populated-plugin";
  };

  "test (plugin): parses license" = {
    expr = fullResult.license;
    expected = "MIT";
  };

  "test (plugin): parses keywords" = {
    expr = fullResult.keywords;
    expected = [
      "testing"
      "fixture"
      "complete"
    ];
  };

  "test (plugin): parses category" = {
    expr = fullResult.category;
    expected = "development";
  };

  "test (plugin): parses tags" = {
    expr = fullResult.tags;
    expected = [
      "polished"
      "documented"
    ];
  };

  # Minimal fixture: only `name` field present. All optional fields default.

  "test (plugin): minimal manifest defaults description to empty string" = {
    expr = minimalResult.description;
    expected = "";
  };

  "test (plugin): minimal manifest defaults version to null" = {
    expr = minimalResult.version;
    expected = null;
  };

  "test (plugin): minimal manifest defaults keywords to empty list" = {
    expr = minimalResult.keywords;
    expected = [ ];
  };

  "test (plugin): minimal manifest defaults license to null" = {
    expr = minimalResult.license;
    expected = null;
  };
}
