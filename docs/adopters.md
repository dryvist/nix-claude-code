# Adopter guide

How to consume `nix-claude-code` from your own flake.

## Standalone home-manager (the 95% answer)

See [`templates/minimal/`](../templates/minimal/) for a working starter. The shape:

```nix
{
  inputs.nix-claude-code = {
    url = "github:JacobPEvans/nix-claude-code";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };

  outputs = { home-manager, nix-claude-code, ... }: {
    homeConfigurations.you = home-manager.lib.homeManagerConfiguration {
      modules = [ nix-claude-code.homeModules.default ./home.nix ];
      # ...
    };
  };
}
```

## flake-parts

See [`templates/flake-parts/`](../templates/flake-parts/). Use the `flakeModule` export
to plug into a flake-parts assembly:

```nix
imports = [ inputs.nix-claude-code.flakeModule ];
```

## Picking individual modules

If you only want some subset:

```nix
modules = [
  nix-claude-code.homeModules.core      # settings.json + permissions + binary
  nix-claude-code.homeModules.plugins   # marketplaces + plugin management
  # skip statusline, hooks, mcp, latest
];
```

## Wiring MCP servers

`nix-claude-code` only surfaces the option — you populate it from your own runtime:

```nix
{
  programs.claude.mcpServers = {
    my-server = {
      command = "${pkgs.my-mcp-server}/bin/my-mcp-server";
      args = [];
      env = {};
    };
  };
}
```

If you use [JacobPEvans/nix-ai](https://github.com/JacobPEvans/nix-ai), the integration is
already wired: `programs.claude.mcpServers = config.programs.aiMcp.servers`.

## Consuming the lib from another flake

For AI tools that aren't Claude Code (Codex, Gemini, agent-skills), import only the lib:

```nix
{ inputs, ... }:
let
  perms = inputs.nix-claude-code.lib.mkDefaultPermissions { tool = "codex"; };
in {
  # apply perms.allow / perms.deny / perms.webfetchDomains
}
```

## Overriding inputs

Use `follows` to align with your own pins:

```nix
inputs.nix-claude-code = {
  url = "github:JacobPEvans/nix-claude-code";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
  inputs.claude-plugins-official.follows = "claude-plugins-official";
  # ...etc. for any marketplace you pin in your own flake
};
```
