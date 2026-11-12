# `programs.claude.settings.effortLevel` render checks for nix-claude-code.
# Kept in its own file, with its own mkActivation copy, so
# ./activation.nix stays under the 12KB per-file size gate — the same
# reason ./config-dir.nix and ./auto-compact.nix were split out of it.
{
  inputs,
  self,
  pkgs,
  lib,
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

  effortLevelSet = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      settings.effortLevel = "medium";
    };
  };

  effortLevelUnset = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
    };
  };

  # The top-level alias in options-runtime.nix must keep rendering on its own.
  effortLevelTopLevelAlias = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      effortLevel = "high";
    };
  };

  # Precedence: the curated `settings` option wins over the top-level alias.
  effortLevelBothSet = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      effortLevel = "high";
      settings.effortLevel = "medium";
    };
  };
in
{
  claude-effort-level-render =
    pkgs.runCommand "claude-effort-level-render-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json() {
          grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' "$1/activate" | head -1
        }
        expect() {
          local file="$1" filter="$2" want="$3" got
          got=$(jq -c "$filter" "$file")
          [[ "$got" == "$want" ]] || {
            echo "$filter: expected $want, got $got" >&2
            exit 1
          }
        }
        expect "$(settings_json ${effortLevelSet})" '.effortLevel' '"medium"'
        expect "$(settings_json ${effortLevelUnset})" 'has("effortLevel")' 'false'
        expect "$(settings_json ${effortLevelTopLevelAlias})" '.effortLevel' '"high"'
        expect "$(settings_json ${effortLevelBothSet})" '.effortLevel' '"medium"'
        echo ok > $out
      '';
}
