# Home-manager activation checks for nix-claude-code.
# Extracted from flake/checks.nix to stay under the 12KB per-file size gate.
{
  inputs,
  self,
  pkgs,
  ...
}:
let
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
        package = null;
        statusline = {
          enable = true;
          inherit theme;
        };
      };
    };

  programsClaudeEval = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
    };
  };

  hooksRegistrationActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      hooks.refreshMarketplaces = true;
    };
  };

  outputStyleActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      outputStyle = "concise";
    };
  };

  configDirActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      configDir = ".config/claude";
      # Enabled so the checks below can inspect the *deployed* runtime
      # scripts (the marketplace-refresh hook, the daniel3303 statusline) —
      # activation-text greps can't see hard-coded paths baked into them.
      hooks.refreshMarketplaces = true;
      statusline = {
        enable = true;
        theme = "daniel3303";
      };
    };
  };

  sessionVarsRelPath = "home-path/etc/profile.d/hm-session-vars.sh";
  # Exercises the sandbox sub-keys and one policy key. Before the renderer
  # emitted the whole attrset, everything except enabled /
  # autoAllowBashIfSandboxed / excludedCommands was dropped, so this fixture
  # fails against the old behaviour.
  sandboxPolicyActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      settings = {
        sandbox = {
          enabled = true;
          network = {
            allowUnixSockets = [ "/tmp/example.sock" ];
          };
          filesystem = {
            allowWritePaths = [ "/tmp/example" ];
          };
          failIfUnavailable = true;
        };
        disableSkillShellExecution = true;
        minimumVersion = "2.1.251";
      };
    };
  };

  claudeSwapDefaultDisabled =
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
      ];
    }).config.programs.claude.swap.disabled;

  claudeSwapPackage = import ../../packages/claude-swap.nix {
    inherit pkgs;
    src = inputs.claude-swap;
  };
in
{
  programs-claude-eval = programsClaudeEval;

  statusline-powerline = mkStatuslineCheck "powerline";
  statusline-ccstatusline = mkStatuslineCheck "ccstatusline";
  statusline-daniel3303 = mkStatuslineCheck "daniel3303";

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
        expect 'has("outputStyle")' 'false'
        echo ok > $out
      '';

  # Regression: every sandbox sub-key a caller sets must reach settings.json.
  # `sandbox` is in settings.nix's `knownSettingsKeys`, so it is excluded from
  # the freeform passthrough — when the renderer named sub-keys individually,
  # anything else was silently discarded.
  sandbox-policy-render =
    pkgs.runCommand "sandbox-policy-render-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
          ${sandboxPolicyActivation}/activate | head -1)

        expect() {
          local filter="$1" want="$2" got
          got=$(jq -c "$filter" "$settings_json")
          [[ "$got" == "$want" ]] || {
            echo "$filter: expected $want, got $got" >&2
            exit 1
          }
        }

        # The three that always worked.
        expect '.sandbox.enabled' 'true'
        expect '.sandbox.autoAllowBashIfSandboxed' 'true'
        # The ones that used to be dropped.
        expect '.sandbox.failIfUnavailable' 'true'
        expect '.sandbox.network.allowUnixSockets' '["/tmp/example.sock"]'
        expect '.sandbox.filesystem.allowWritePaths' '["/tmp/example"]'
        # Unset sub-keys stay absent rather than emitting an explicit null.
        expect '.sandbox | has("ignoreViolations")' 'false'
        expect '.sandbox | has("excludedCommands")' 'false'
        # Policy keys render at the top level.
        expect '.disableSkillShellExecution' 'true'
        expect '.minimumVersion' '"2.1.251"'
        echo ok > $out
      '';

  # Every new policy/sandbox option defaults to null, so a consumer that sets
  # none of them gets a settings.json with none of them present. This is the
  # "stays absent unless a consumer sets it" class this repo owns.
  policy-options-default-absent =
    pkgs.runCommand "policy-options-default-absent-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
          ${programsClaudeEval}/activate | head -1)

        for key in disableAllHooks allowedHttpHookUrls httpHookAllowedEnvVars \
                   disableSkillShellExecution disableBundledSkills claudeMdExcludes \
                   enabledMcpjsonServers disabledMcpjsonServers allowedMcpServers \
                   deniedMcpServers disableRemoteControl minimumVersion; do
          got=$(jq -c --arg k "$key" 'has($k)' "$settings_json")
          [[ "$got" == "false" ]] || {
            echo "$key: expected absent by default, got present" >&2
            exit 1
          }
        done

        # sandbox is gated on enabled=false by default, so the whole key is absent.
        got=$(jq -c 'has("sandbox")' "$settings_json")
        [[ "$got" == "false" ]] || {
          echo "sandbox: expected absent when disabled, got present" >&2
          exit 1
        }
        echo ok > $out
      '';

  output-style-render =
    pkgs.runCommand "output-style-render-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
          ${outputStyleActivation}/activate | head -1)
        got=$(jq -r '.outputStyle // empty' "$settings_json")
        [[ "$got" == "concise" ]] || {
          echo "expected outputStyle to be concise, got: $got" >&2
          exit 1
        }
        echo ok > $out
      '';

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

  # Hard requirement (see the configDir option's own description): leaving
  # configDir unset must reproduce today's behavior byte-for-byte. No
  # CLAUDE_CONFIG_DIR export, and every Nix-managed path still anchored at
  # ~/.claude — the same activation used by every other check in this file.
  config-dir-default-unchanged =
    pkgs.runCommand "config-dir-default-unchanged-test"
      {
        SESSION_VARS = "${programsClaudeEval}/${sessionVarsRelPath}";
      }
      ''
        set -euo pipefail
        grep -q 'CLAUDE_CONFIG_DIR' "$SESSION_VARS" && {
          echo "expected no CLAUDE_CONFIG_DIR export at the default configDir, but found one in $SESSION_VARS" >&2
          exit 1
        }
        grep -q '/\.claude/settings\.json' ${programsClaudeEval}/activate || {
          echo "expected the settings.json merge target to still be under .claude at the default configDir" >&2
          exit 1
        }
        echo ok > $out
      '';

  # Setting configDir must relocate every Nix-written path (not just
  # settings.json) and export CLAUDE_CONFIG_DIR to match, so the module and
  # the `claude` binary can never disagree about where the config tree lives.
  config-dir-relocates-paths =
    pkgs.runCommand "config-dir-relocates-paths-test"
      {
        SESSION_VARS = "${configDirActivation}/${sessionVarsRelPath}";
      }
      ''
        set -euo pipefail
        grep -q 'CLAUDE_CONFIG_DIR="/tmp/ci-tester-home/\.config/claude"' "$SESSION_VARS" || {
          echo "expected CLAUDE_CONFIG_DIR to be exported pointing at .config/claude, got:" >&2
          cat "$SESSION_VARS" >&2
          exit 1
        }
        grep -q '/\.config/claude/settings\.json' ${configDirActivation}/activate || {
          echo "expected the settings.json merge target under .config/claude" >&2
          exit 1
        }
        grep -q '/\.config/claude/plugins/known_marketplaces\.json' ${configDirActivation}/activate || {
          echo "expected the known_marketplaces.json merge target under .config/claude" >&2
          exit 1
        }
        grep -q '\.claude/' ${configDirActivation}/activate && {
          echo "found a leftover hardcoded .claude/ path in a custom-configDir activation" >&2
          exit 1
        }
        echo ok > $out
      '';

  # The runtime helper scripts (marketplace-refresh hook, daniel3303
  # statusline) are static files — Nix can't rewrite `.claude` paths inside
  # them, so they must read CLAUDE_CONFIG_DIR at runtime. Inspect the
  # *deployed* artifacts (not the sources) to prove they do, and that no
  # bare `$HOME/.claude` config path survives in them.
  config-dir-runtime-scripts =
    pkgs.runCommand "config-dir-runtime-scripts-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail

        # --- marketplace-refresh hook: deployed under the configured dir ---
        hook="${configDirActivation}/home-files/.config/claude/hooks/session-start.sh"
        [[ -f "$hook" ]] || {
          echo "marketplace-refresh hook not deployed at .config/claude/hooks/session-start.sh" >&2
          exit 1
        }
        grep -q 'CLAUDE_CONFIG_DIR' "$hook" || {
          echo "deployed marketplace-refresh hook does not honor CLAUDE_CONFIG_DIR:" >&2
          cat "$hook" >&2
          exit 1
        }
        grep -Eq '\$\{?HOME\}?/\.claude/plugins' "$hook" && {
          echo "deployed marketplace-refresh hook still hard-codes \$HOME/.claude/plugins" >&2
          exit 1
        }

        # --- daniel3303 statusline: follow settings.json -> wrapper -> script ---
        settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
          ${configDirActivation}/activate | head -1)
        wrapper=$(jq -r '.statusLine.command' "$settings_json")
        [[ -f "$wrapper" ]] || {
          echo "statusline command $wrapper is not a readable file" >&2
          exit 1
        }
        # The wrapper execs the vendored bash script by store path; pull it out.
        script=$(grep -o '/nix/store/[a-z0-9]*-claude-statusline\.sh' "$wrapper" | head -1)
        [[ -n "$script" && -f "$script" ]] || {
          echo "could not resolve the daniel3303 statusline script from $wrapper" >&2
          cat "$wrapper" >&2
          exit 1
        }
        grep -q 'CLAUDE_CONFIG_DIR' "$script" || {
          echo "deployed daniel3303 statusline does not honor CLAUDE_CONFIG_DIR" >&2
          exit 1
        }
        grep -Eq '"\$HOME/\.claude/settings\.json"|\$\{HOME\}/\.claude/\.credentials\.json' "$script" && {
          echo "deployed daniel3303 statusline still hard-codes a \$HOME/.claude config path" >&2
          exit 1
        }

        echo ok > $out
      '';

  claude-swap-default-disabled =
    assert claudeSwapDefaultDisabled;
    pkgs.runCommand "claude-swap-default-disabled-test" { } ''
      echo ok > $out
    '';

  claude-swap-package = pkgs.runCommand "claude-swap-package-test" { } ''
    test -x ${claudeSwapPackage}/bin/cswap
    test -x ${claudeSwapPackage}/bin/claude-swap
    ${claudeSwapPackage}/bin/cswap --help > /dev/null
    echo ok > $out
  '';
}
