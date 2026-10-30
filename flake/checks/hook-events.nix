{ pkgs, mkActivation }:
let
  hooksRegistrationActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      hooks.refreshMarketplaces = true;
    };
  };

  hooksMergeActivation = mkActivation {
    imports = [
      {
        programs.claude.hooks.events.SessionStart = [
          {
            hooks = [
              {
                command = "caller-hook";
                type = "command";
              }
            ];
          }
        ];
      }
      {
        programs.claude.hooks.events.SessionStart = [
          {
            hooks = [
              {
                command = "integration-hook";
                type = "command";
              }
            ];
          }
        ];
      }
    ];
    programs.claude = {
      enable = true;
      package = null;
      hooks.refreshMarketplaces = true;
    };
  };

  hooksLegacyOverrideActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
      hooks.refreshMarketplaces = true;
      hooks.events.Stop = [
        {
          hooks = [
            {
              command = "added-stop";
              type = "command";
            }
          ];
        }
      ];
      settings.hooks.LegacyFixture = {
        untouched = true;
      };
      settings.hooks.SessionStart = [
        {
          hooks = [
            {
              command = "legacy-hook";
              type = "command";
            }
          ];
        }
      ];
    };
  };
in
{
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
        # The refresh must not block session start or re-run on resume/compact.
        jq -e '.hooks.SessionStart[0] | .matcher == "startup" and .hooks[0].async == true and .hooks[0].timeout == 300' \
          "$settings_json" >/dev/null || {
          echo "expected refresh SessionStart hook: matcher=startup, async=true, timeout=300; got:" >&2
          jq '.hooks.SessionStart' "$settings_json" >&2
          exit 1
        }
        echo ok > $out
      '';

  hooks-merge = pkgs.runCommand "hooks-merge-test" { nativeBuildInputs = [ pkgs.jq ]; } ''
    set -euo pipefail
    settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
      ${hooksMergeActivation}/activate | head -1)
    jq -e '
      .hooks.SessionStart as $events |
      ($events | length == 3) and
      ([$events[].hooks[].command] | any(. == "caller-hook")) and
      ([$events[].hooks[].command] | any(. == "integration-hook")) and
      ($events | any(.matcher == "startup" and
        (.hooks[0].command | endswith("/.claude/hooks/session-start.sh")) and
        .hooks[0].async == true and .hooks[0].timeout == 300))
    ' "$settings_json" > /dev/null
    echo ok > $out
  '';

  hooks-legacy-override =
    pkgs.runCommand "hooks-legacy-override-test" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        set -euo pipefail
        settings_json=$(grep -o '/nix/store/[a-z0-9]*-claude-settings\.json' \
          ${hooksLegacyOverrideActivation}/activate | head -1)
        jq -e '(.hooks.SessionStart | length == 1 and .[0].hooks[0].command == "legacy-hook") and
          .hooks.LegacyFixture == {"untouched": true} and .hooks.Stop[0].hooks[0].command == "added-stop"' \
          "$settings_json" > /dev/null
        echo ok > $out
      '';
}
