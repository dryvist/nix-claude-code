# merge-json-settings.sh regression fixtures. Each subdirectory under
# ./tests/merge-json-settings is one scenario: an existing-settings.json
# (runtime state before merge), a nix-settings.json (this activation's
# rendered settings), and the expected-settings.json the merge must
# produce. Adding a scenario is adding a directory — no Nix changes
# needed. Each scenario runs the actual script under test and compares
# its (jq -S canonicalized) output against the fixture via nixpkgs'
# native testEqualContents (diffoscope), not custom comparison logic.
{ pkgs, lib }:
let
  testsDir = ./tests/merge-json-settings;
  scenarios = builtins.attrNames (builtins.readDir testsDir);
in
lib.listToAttrs (
  map (scenarioName: {
    name = "merge-json-settings-${scenarioName}";
    value =
      let
        fixture = testsDir + "/${scenarioName}";
        actual =
          pkgs.runCommand "merge-json-settings-${scenarioName}-actual" { nativeBuildInputs = [ pkgs.jq ]; }
            ''
              cp ${fixture}/existing-settings.json target.json
              bash ${../../modules/scripts/merge-json-settings.sh} ${fixture}/nix-settings.json target.json
              jq -S . target.json > $out
            '';
        expected =
          pkgs.runCommand "merge-json-settings-${scenarioName}-expected" { nativeBuildInputs = [ pkgs.jq ]; }
            ''
              jq -S . ${fixture}/expected-settings.json > $out
            '';
      in
      pkgs.testers.testEqualContents {
        assertion = "merge-json-settings (${scenarioName}): actual merged settings match the expected fixture";
        inherit actual expected;
      };
  }) scenarios
)
