{
  description = "Declarative Claude Code in Nix — plugins, marketplaces, skills, hooks, MCP, and permissions as composable home-manager modules. Reproducible on macOS and Linux.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ai-assistant-instructions = {
      url = "github:JacobPEvans/ai-assistant-instructions";
      flake = false;
    };

    claude-code-plugins = {
      url = "github:anthropics/claude-code";
      flake = false;
    };
    claude-cookbooks = {
      url = "github:anthropics/claude-cookbooks";
      flake = false;
    };
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    anthropic-agent-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    bills-claude-skills = {
      url = "github:BillChirico/bills-claude-skills";
      flake = false;
    };
    bitwarden-marketplace = {
      url = "github:bitwarden/ai-plugins";
      flake = false;
    };
    cc-dev-tools = {
      url = "github:Lucklyric/cc-dev-tools";
      flake = false;
    };
    cc-marketplace = {
      url = "github:ananddtyagi/cc-marketplace";
      flake = false;
    };
    claude-code-plugins-plus = {
      url = "github:jeremylongshore/claude-code-plugins-plus";
      flake = false;
    };
    claude-code-workflows = {
      url = "github:wshobson/agents";
      flake = false;
    };
    claude-skills = {
      url = "github:secondsky/claude-skills";
      flake = false;
    };
    jacobpevans-cc-plugins = {
      url = "github:JacobPEvans/claude-code-plugins";
      flake = false;
    };
    lunar-claude = {
      url = "github:basher83/lunar-claude";
      flake = false;
    };
    obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };
    openai-codex = {
      url = "github:openai/codex-plugin-cc";
      flake = false;
    };
    axton-obsidian-visual-skills = {
      url = "github:axtonliu/axton-obsidian-visual-skills";
      flake = false;
    };
    superpowers-marketplace = {
      url = "github:obra/superpowers-marketplace";
      flake = false;
    };
    visual-explainer-marketplace = {
      url = "github:nicobailon/visual-explainer";
      flake = false;
    };
    wakatime = {
      url = "github:wakatime/claude-code-wakatime";
      flake = false;
    };
    huggingface-skills = {
      url = "github:huggingface/skills";
      flake = false;
    };

    browser-use-skills = {
      url = "github:browser-use/browser-use";
      flake = false;
    };
    vct-cribl-pack-validator-skills = {
      url = "github:VisiCore/vct-cribl-pack-validator";
      flake = false;
    };

    fabric-src = {
      url = "github:danielmiessler/fabric";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [
        ./flake/modules.nix
        ./flake/lib.nix
        ./flake/treefmt.nix
        ./flake/git-hooks.nix
        ./flake/checks.nix
        ./flake/dev-shell.nix
        ./flake/templates.nix
      ];
    };
}
