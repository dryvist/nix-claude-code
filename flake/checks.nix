{ inputs, self, ... }:
{
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
        discoverCommands = import ../checks/lib/discover-commands.nix { inherit lib; };
        discoverAgents = import ../checks/lib/discover-agents.nix { inherit lib; };
        discoverHooks = import ../checks/lib/discover-hooks.nix { inherit lib; };
        parseMarketplace = import ../checks/lib/parse-marketplace.nix { inherit lib; };
        parsePlugin = import ../checks/lib/parse-plugin.nix { inherit lib; };
        toSettingsJson = import ../checks/lib/to-settings-json.nix { inherit lib; };
      };

      allTests = lib.foldl' (acc: suite: acc // suite) { } (builtins.attrValues suites);
      failures = lib.runTests allTests;

      # wrap-commands-as-skills needs `pkgs.runCommand`, so its test is a
      # real derivation rather than a pure-Nix value comparison.
      discoverCommands = import ../lib/discover-commands.nix { inherit lib; };
      wrapCommandsAsSkills = import ../lib/wrap-commands-as-skills.nix { inherit lib pkgs; };
      pluginFixture = ../checks/lib/fixtures/plugin-with-components;
      synthesizedSkills = wrapCommandsAsSkills {
        commands = discoverCommands pluginFixture;
        name = "synthesized-skills-fixture";
      };

      # Build a minimal home-manager activation derivation with the given
      # extra module slotted in. Lets us assert that each statusline theme
      # evaluates cleanly and produces a buildable activation package.
      mkActivation =
        extraModule:
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
            }
            extraModule
          ];
        }).activationPackage;

      mkStatuslineCheck =
        theme:
        mkActivation {
          programs.claude = {
            enable = true;
            # `claude-code` is unfree; the activation check exercises
            # module wiring only, so skip the binary install.
            package = null;
            statusline = {
              enable = true;
              inherit theme;
            };
          };
        };
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

        statusline-powerline = mkStatuslineCheck "powerline";
        statusline-ccstatusline = mkStatuslineCheck "ccstatusline";
        statusline-daniel3303 = mkStatuslineCheck "daniel3303";

        wrap-commands-as-skills = pkgs.runCommand "wrap-commands-as-skills-test" { } ''
          set -euo pipefail
          # Verify the synthesized tree exists and the two expected skills
          # (`build`, `test` — from the plugin-with-components fixture)
          # ended up with valid SKILL.md files containing frontmatter.
          test -d ${synthesizedSkills}/skills/build
          test -d ${synthesizedSkills}/skills/test
          grep -q '^name: build$' ${synthesizedSkills}/skills/build/SKILL.md
          grep -q '^name: test$' ${synthesizedSkills}/skills/test/SKILL.md
          grep -q '^description:' ${synthesizedSkills}/skills/build/SKILL.md
          # The `not-a-command.txt` file in the fixture must be ignored.
          test ! -e ${synthesizedSkills}/skills/not-a-command
          echo ok > $out
        '';
      };
    };
}
