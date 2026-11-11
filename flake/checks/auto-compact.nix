{ pkgs, mkActivation }:
let
  autoCompactWindowSet = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      settings.autoCompactWindow = "500000";
    };
  };

  autoCompactWindowUnset = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
    };
  };
in
{
  claude-auto-compact-window-render =
    pkgs.runCommand "claude-auto-compact-window-render-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json() {
          grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' "$1/activate" | head -1
        }
        set_json=$(settings_json ${autoCompactWindowSet})
        unset_json=$(settings_json ${autoCompactWindowUnset})
        jq -e '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW == "500000"' "$set_json" > /dev/null
        jq -e 'has("autoCompactWindow") | not' "$set_json" > /dev/null
        jq -e '(.env // {}) | has("CLAUDE_CODE_AUTO_COMPACT_WINDOW") | not' "$unset_json" > /dev/null
        echo ok > $out
      '';
}
