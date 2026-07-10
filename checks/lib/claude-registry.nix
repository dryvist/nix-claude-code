{ lib }:
let
  reg = import ../../lib/claude-registry.nix {
    inherit lib;
    homeDir = "/home/tester";
  };

  github = reg.toClaudeMarketplaceFormat "ponytail" {
    source = {
      type = "github";
      url = "DietrichGebert/ponytail";
    };
  };

  # Synthetic marketplace: upstream repo has no marketplace.json, so it must
  # become a local "directory" source instead of a git-cloned "github" one.
  local = reg.toClaudeMarketplaceFormat "fabric-patterns" {
    source = {
      type = "local";
      url = "danielmiessler/fabric";
    };
  };
in
{
  "test (registry): github type stays a github source with repo" = {
    expr = github.source;
    expected = {
      source = "github";
      repo = "DietrichGebert/ponytail";
    };
  };

  "test (registry): local type becomes a directory source" = {
    expr = local.source.source;
    expected = "directory";
  };

  "test (registry): local directory path is the Nix-managed marketplace dir" = {
    expr = local.source.path;
    expected = "/home/tester/.claude/plugins/marketplaces/fabric-patterns";
  };

  "test (registry): directory source omits the github repo field" = {
    expr = builtins.hasAttr "repo" local.source;
    expected = false;
  };
}
