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
        claudeRegistry = import ../checks/lib/claude-registry.nix { inherit lib; };
        parsePlugin = import ../checks/lib/parse-plugin.nix { inherit lib; };
        toSettingsJson = import ../checks/lib/to-settings-json.nix { inherit lib; };
        renderAutonomous = import ../checks/lib/render-autonomous.nix { inherit lib; };
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

      # See ./checks/merge-json-settings.nix — kept out of this file to
      # stay under the file-size gate's per-file limit.
      mergeJsonSettingsChecks = import ./checks/merge-json-settings.nix { inherit pkgs lib; };

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

      # Bare-minimum activation: verifies the full `programs.claude` option
      # set evaluates cleanly with only `enable = true;`. Catches schema
      # regressions (e.g. typed options that demand non-default input,
      # cross-option assertions firing for empty configs).
      programsClaudeEval = mkActivation {
        programs.claude = {
          enable = true;
          package = null; # claude-code is unfree; skip the binary install.
        };
      };

      # Regression guard for the typed-hooks → settings.json registration
      # bug: writing ~/.claude/hooks/session-start.sh alone does nothing,
      # since Claude Code only invokes hooks registered under settings.json's
      # `hooks` key. Asserts refreshMarketplaces actually produces that
      # registration, not just the script file.
      hooksRegistrationActivation = mkActivation {
        programs.claude = {
          enable = true;
          package = null;
          hooks.refreshMarketplaces = true;
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

        # The autonomous profile (bypassPermissions, and the Codex/agy
        # equivalents) is only safe inside a container, where the boundary
        # is the safety model. On a workstation there is no such boundary.
        # This fails the build if any home-manager module imports the
        # autonomous renderers or assigns one of those postures — the
        # shared check from dryvist/.github, so all per-CLI repos enforce
        # the same rule. Declaring the values in a types.enum and
        # describing them in prose stays legal; only assignment is flagged.
        autonomous-containment = inputs.dryvist-github.lib.autonomousContainment {
          inherit pkgs;
          homeManagerModules = ../modules;
        };

        statusline-powerline = mkStatuslineCheck "powerline";
        statusline-ccstatusline = mkStatuslineCheck "ccstatusline";
        statusline-daniel3303 = mkStatuslineCheck "daniel3303";

        # Eval-time regression guard for the `programs.claude` module schema.
        programs-claude-eval = programsClaudeEval;

        # The auto-mode-only permission posture, asserted against the file
        # that actually gets deployed rather than against option defaults.
        # A default `programs.claude.enable = true` must ship no allow, ask,
        # or deny rules: the classifier is the only gate, and nothing may
        # resolve before it. `askUserQuestionTimeout` is checked here too —
        # upstream's default is "never", so a regression to it would let a
        # dialog hold a session open indefinitely. `advisorModel` must stay
        # absent by default too — it's opt-in because the advisor tool
        # forwards the whole conversation transcript to a reviewer model.
        claude-settings-render =
          pkgs.runCommand "claude-settings-render-test" { nativeBuildInputs = [ pkgs.jq ]; }
            ''
              set -euo pipefail
              settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
                ${programsClaudeEval}/activate | head -1)

              expect() {
                local filter="$1" want="$2" got
                got=$(jq -c "$filter" "$settings_json")
                [[ "$got" == "$want" ]] || {
                  echo "$filter: expected $want, got $got" >&2
                  exit 1
                }
              }

              expect '.permissions.allow' '[]'
              expect '.permissions.ask' '[]'
              expect '.permissions.deny' '[]'
              expect '.permissions.defaultMode' '"auto"'
              expect '.autoMode.classifyAllShell' 'true'
              expect '.askUserQuestionTimeout' '"5m"'
              expect '.useAutoModeDuringPlan' 'true'
              expect 'has("advisorModel")' 'false'
              echo ok > $out
            '';

        # Asserts `hooks.refreshMarketplaces` actually registers
        # ~/.claude/hooks/session-start.sh under settings.json's `hooks` key
        # — the whole point of the typed hook, not just the file existing.
        hooks-registration =
          pkgs.runCommand "hooks-registration-test" { nativeBuildInputs = [ pkgs.jq ]; }
            ''
              set -euo pipefail
              settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
                ${hooksRegistrationActivation}/activate | head -1)
              command=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$settings_json")
              [[ "$command" == *".claude/hooks/session-start.sh" ]] || {
                echo "expected hooks.SessionStart to register session-start.sh, got: $command" >&2
                exit 1
              }
              echo ok > $out
            '';

        # The private-workspace Agent guard, end to end against a stubbed
        # /model/info: an external `subagent` deployment denies, a
        # loopback-local one stays silent, a spawn outside the private
        # workspace passes, and an unreachable endpoint fails open.
        private-workspace-agent-guard = pkgs.runCommand "private-workspace-agent-guard-test" {
          nativeBuildInputs = [
            pkgs.jq
            pkgs.bash
          ];
          GUARD = ../modules/hooks/private-workspace-agent-guard.sh;
        } "bash ${../scripts/private-workspace-agent-guard-test.sh}";

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

        # Regression guard: claude-json-merge.sh's final chmod must not abort
        # activation when it fails (e.g. ~/.claude.json owned by a different
        # user). Runs the script exactly as home-manager sources it, under
        # set -eu -o pipefail, with a stub `chmod` on PATH that always fails
        # — standing in as a permission error, which a sandboxed build can't
        # otherwise fabricate. Before the fix this aborted the whole build;
        # after, it must exit 0 and log a warning naming the file.
        claude-json-merge-chmod-soft-fail =
          pkgs.runCommand "claude-json-merge-chmod-soft-fail-test" { nativeBuildInputs = [ pkgs.jq ]; }
            ''
              set -euo pipefail
              export HOME=$(mktemp -d)
              echo '{}' > "$HOME/.claude.json"

              fakebin=$(mktemp -d)
              printf '#!/bin/sh\nexit 1\n' > "$fakebin/chmod"
              chmod +x "$fakebin/chmod"
              export PATH="$fakebin:$PATH"

              export OVERLAY_FILE=$(mktemp)
              echo '{"mcpServers":{}}' > "$OVERLAY_FILE"
              export TRUSTED_PROJECT_DIRS='[]'
              export DRY_RUN_CMD=""

              set +e
              bash -euo pipefail -c ". ${../modules/scripts/claude-json-merge.sh}" 2>stderr.log
              rc=$?
              set -e

              [ "$rc" -eq 0 ] || {
                echo "activation aborted when chmod failed (rc=$rc):" >&2
                cat stderr.log >&2
                exit 1
              }
              grep -q "claude.json" stderr.log || {
                echo "expected a warning naming the file on chmod failure, got:" >&2
                cat stderr.log >&2
                exit 1
              }
              echo ok > $out
            '';

      }
      // mergeJsonSettingsChecks;
    };
}
