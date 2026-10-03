# The official plugin is self-contained and opt-in for standalone consumers.
{
  inputs,
  self,
  pkgs,
  lib,
}:
let
  evaluate =
    enabled:
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
            plugins.enabled = lib.optionalAttrs (enabled != null) {
              "codex@openai-codex" = enabled;
            };
          };
        }
      ];
    }).config;

  enabled = evaluate true;
  disabled = evaluate false;
  defaults = evaluate null;
  marketplace = enabled.programs.claude.plugins.marketplaces.openai-codex;
  runtimePaths = [
    ".claude-plugin/marketplace.json"
    "plugins/codex/commands/rescue.md"
    "plugins/codex/agents/codex-rescue.md"
    "plugins/codex/skills/codex-cli-runtime/SKILL.md"
    "plugins/codex/scripts/codex-companion.mjs"
    "plugins/codex/scripts/app-server-broker.mjs"
  ];
in
{
  codex-plugin-native-delivery =
    assert lib.assertMsg (
      !(defaults.programs.claude.plugins.marketplaces ? openai-codex)
    ) "Codex marketplace must remain opt-in";
    assert lib.assertMsg (
      !(disabled.programs.claude.plugins.marketplaces ? openai-codex)
    ) "Disabling Codex must not register its marketplace";
    assert lib.assertMsg (
      toString marketplace.flakeInput == toString inputs.openai-codex
    ) "Codex must use the complete, unmodified upstream plugin tree";
    assert lib.assertMsg (
      marketplace.source.url == "openai/codex-plugin-cc"
    ) "Codex marketplace must use the official source";
    assert lib.assertMsg (lib.all (
      path: builtins.pathExists "${marketplace.flakeInput}/${path}"
    ) runtimePaths) "Codex marketplace is missing a command, agent, helper, or app-server runtime";
    assert lib.assertMsg (
      enabled.home.activation ? claudeMarketplaceStableLinks
    ) "Codex marketplace must use stable activation links";
    assert lib.assertMsg (lib.all (path: !(lib.hasPrefix ".claude/plugins/marketplaces/" path)) (
      lib.attrNames enabled.home.file
    )) "Codex marketplace must not be delivered through home.file";
    assert lib.assertMsg
      (builtins.elem "openai-codex" self.lib.marketplaceCatalog.claudeOnlyMarketplaces)
      "Codex must be classified as Claude-only for shared-skill consumers";
    pkgs.runCommand "codex-plugin-native-delivery" { } ''
      echo ok > $out
    '';
}
