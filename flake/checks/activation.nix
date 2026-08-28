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
    };
  };

  sessionVarsRelPath = "home-path/etc/profile.d/hm-session-vars.sh";
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
}
