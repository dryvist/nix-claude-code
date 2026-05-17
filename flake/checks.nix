_: {
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      # Each *.nix file under ./checks/lib returns an attrset of
      # `{ "test name" = { expr; expected; }; }` cases. `lib.runTests`
      # evaluates the union and returns a list of failures (empty when all
      # pass). Suites are merged before evaluation so a single check
      # derivation reports the full pass/fail picture.
      suites = {
        permissions = import ../checks/lib/permissions.nix { inherit lib; };
        discoverSkills = import ../checks/lib/discover-skills.nix { inherit lib; };
        parseMarketplace = import ../checks/lib/parse-marketplace.nix { inherit lib; };
      };

      allTests = lib.foldl' (acc: suite: acc // suite) { } (builtins.attrValues suites);
      failures = lib.runTests allTests;
    in
    {
      checks = {
        lib-tests =
          if failures == [ ] then
            pkgs.runCommand "nix-claude-code-lib-tests" { } ''
              echo "All ${toString (builtins.length (builtins.attrNames allTests))} lib tests passed." > $out
            ''
          else
            pkgs.runCommand "nix-claude-code-lib-tests" { } ''
              cat <<'FAILURES'
              Failed lib tests:
              ${builtins.toJSON failures}
              FAILURES
              exit 1
            '';
      };
    };
}
