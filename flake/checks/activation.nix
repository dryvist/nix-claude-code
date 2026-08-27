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
}
