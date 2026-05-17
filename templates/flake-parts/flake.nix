{
  description = "Claude Code via nix-claude-code — flake-parts setup";

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

    nix-claude-code = {
      url = "github:dryvist/nix-claude-code";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      imports = [ inputs.home-manager.flakeModules.home-manager ];
      flake = {
        homeConfigurations."you" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs { system = "aarch64-darwin"; };
          modules = [
            inputs.nix-claude-code.homeModules.default
            (_: {
              home = {
                username = "you";
                homeDirectory = "/Users/you";
                stateVersion = "25.11";
              };
              programs.claude.enable = true;
            })
          ];
        };
      };
    };
}
