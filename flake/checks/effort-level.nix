# `programs.claude.settings.effortLevel` render checks for nix-claude-code.
# Kept in its own file, with its own mkActivation copy, so
# ./activation.nix stays under the 12KB per-file size gate — the same
# reason ./config-dir.nix and ./auto-compact.nix were split out of it.
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

  # The "stays absent unless a consumer sets it" class this repo owns:
  # with nothing set, the generated settings.json carries no effort key.
  effortLevelUnset = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
    };
  };

  effortLevelSet = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      settings.effortLevel = "medium";
    };
  };

  # The top-level alias in options-runtime.nix must keep rendering on its own.
  effortLevelAlias = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      effortLevel = "high";
    };
  };
in
{
  claude-effort-level-unset =
    pkgs.runCommand "claude-effort-level-unset-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
          ${effortLevelUnset}/activate | head -1)
        got=$(jq -c 'has("effortLevel")' "$settings_json")
        [[ "$got" == "false" ]] || {
          echo "effortLevel: expected absent by default, got present" >&2
          exit 1
        }
        echo ok > $out
      '';

  claude-effort-level-set =
    pkgs.runCommand "claude-effort-level-set-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json() {
          grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' "$1/activate" | head -1
        }
        expect() {
          local file="$1" want="$2" got
          got=$(jq -c '.effortLevel' "$file")
          [[ "$got" == "$want" ]] || {
            echo "effortLevel: expected $want, got $got" >&2
            exit 1
          }
        }
        expect "$(settings_json ${effortLevelSet})" '"medium"'
        expect "$(settings_json ${effortLevelAlias})" '"high"'
        echo ok > $out
      '';
}
