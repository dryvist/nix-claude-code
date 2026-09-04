# Marketplaces must never go back to `home.file`.
#
# `home.file` routes every path through the aggregate `home-manager-files`
# derivation, whose hash covers the whole home configuration. Each marketplace
# symlink then acquired a new target on every rebuild — a shell alias was
# enough — while Claude Code pins an installPath in installed_plugins.json and
# resolves plugin and hook paths once at session start. The result was that any
# rebuild broke every running session until the user reloaded plugins by hand.
#
# The fixture below carries a real flakeInput, so the assertion has something to
# act on. Without it both sides are empty and the check passes while proving
# nothing.
{
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
let
  fixtureMarketplace = pkgs.runCommand "fixture-marketplace" { } ''
    mkdir -p $out/.claude-plugin
    echo '{"name":"fixture-marketplace","plugins":[]}' > $out/.claude-plugin/marketplace.json
  '';

  evaluated =
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        self.homeModules.default
        {
          home = {
            username = "ci-tester";
            homeDirectory = "/tmp/ci-tester-home";
            stateVersion = "25.11";
          };
          programs.claude = {
            enable = true;
            package = null;
            plugins.marketplaces.fixture-marketplace = {
              source = {
                type = "local";
                url = "/dev/null";
              };
              flakeInput = fixtureMarketplace;
            };
          };
        }
      ];
    }).config;

  # Derived from the evaluated config, not a literal: this is a NEGATIVE check
  # (it asserts nothing matching the prefix is in home.file), so a stale
  # hard-coded ".claude" would make it vacuously true the moment a fixture
  # sets programs.claude.configDir, and it would stop testing anything.
  marketplacePrefix = "${evaluated.programs.claude.configDir}/plugins/marketplaces/";
  viaHomeFile = lib.filter (lib.hasPrefix marketplacePrefix) (lib.attrNames evaluated.home.file);
  hasActivationEntry = evaluated.home.activation ? claudeMarketplaceStableLinks;

  # Guards the guard: if the fixture ever stops producing a marketplace, both
  # sides go quiet and this check would pass without testing anything.
  fixtureReachesActivation =
    let
      entry = evaluated.home.activation.claudeMarketplaceStableLinks or null;
    in
    entry != null && lib.hasInfix "claude-marketplaces-stable-links-manifest" (toString entry.data);
in
{
  marketplace-delivery-not-home-file =
    assert lib.assertMsg (viaHomeFile == [ ])
      "marketplaces are delivered via home.file again: ${toString viaHomeFile}. That routes them through the aggregate home-manager-files derivation, so every rebuild moves them and breaks running Claude Code sessions. Deliver them with lib.stableLinks instead.";
    assert lib.assertMsg hasActivationEntry
      "home.activation.claudeMarketplaceStableLinks is missing: marketplaces are no longer linked at their own store paths.";
    assert lib.assertMsg fixtureReachesActivation
      "the fixture marketplace did not reach the activation manifest, so this check proves nothing.";
    pkgs.runCommand "marketplace-delivery-not-home-file-test" { } ''
      echo ok > $out
    '';
}
