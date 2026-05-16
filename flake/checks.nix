_: {
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      checks = {
        lib-tests = pkgs.runCommand "nix-claude-code-lib-tests" { } ''
          echo "lib stub tests pass (real nix-unit suites land with Checkpoint 1 migration)" > $out
        '';
      };
    };
}
