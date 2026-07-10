{ self, inputs, ... }:
let
  marketplaceArgs = {
    inherit (inputs)
      ai-assistant-instructions
      claude-code-plugins
      claude-cookbooks
      claude-plugins-official
      anthropic-agent-skills
      bills-claude-skills
      bitwarden-marketplace
      cc-dev-tools
      cc-marketplace
      claude-code-plugins-plus
      claude-code-workflows
      claude-skills
      jacobpevans-cc-plugins
      karpathy-skills
      lunar-claude
      obsidian-skills
      openai-codex
      axton-obsidian-visual-skills
      superpowers-marketplace
      visual-explainer-marketplace
      wakatime
      huggingface-skills
      browser-use-skills
      vct-cribl-pack-validator-skills
      fabric-src
      ;
  };
  wrap =
    path:
    { ... }:
    {
      imports = [ path ];
      _module.args = marketplaceArgs;
    };
in
{
  flake.homeModules = {
    default = wrap ../modules/default.nix;
    claude = wrap ../modules/default.nix;
    core = wrap ../modules/core.nix;
    plugins = wrap ../modules/plugins.nix;
    statusline = wrap ../modules/statusline;
    hooks = wrap ../modules/hooks.nix;
    mcp = wrap ../modules/mcp.nix;
    latest = wrap ../modules/latest.nix;
    components = wrap ../modules/components.nix;
    registry = wrap ../modules/registry.nix;
    orphan-cleanup = wrap ../modules/orphan-cleanup.nix;
    settings = wrap ../modules/settings.nix;
    claude-json = wrap ../modules/claude-json.nix;
    api-key-helper = wrap ../modules/api-key-helper.nix;
  };

  flake.homeManagerModules = self.homeModules;
}
