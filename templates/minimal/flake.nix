{
  description = "Claude Code via nix-claude-code — minimal home-manager standalone";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-claude-code = {
      url = "github:dryvist/nix-claude-code";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-claude-code,
      ...
    }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."you" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-claude-code.homeModules.default
          ./home.nix
        ];
      };
    };
}
