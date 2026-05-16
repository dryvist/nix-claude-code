_: {
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [ config.treefmt.build.devShell ];
        shellHook = config.pre-commit.installationScript;
        packages = with pkgs; [
          nixfmt-rfc-style
          nil
          nix-tree
          nix-output-monitor
        ];
      };
    };
}
