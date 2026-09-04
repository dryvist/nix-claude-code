# `programs.claude.configDir` checks for nix-claude-code.
# Extracted from ./activation.nix to stay under the 12KB per-file size gate,
# the same reason that file was itself split out of ../checks.nix.
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

  # The `configDir`-unset baseline the default-unchanged check compares against.
  defaultActivation = mkActivation {
    programs.claude = {
      enable = true;
      package = null;
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
in
{

  # Hard requirement (see the configDir option's own description): leaving
  # configDir unset must reproduce today's behavior byte-for-byte. No
  # CLAUDE_CONFIG_DIR export, and every Nix-managed path still anchored at
  # ~/.claude — the same activation used by every other check in this file.
  config-dir-default-unchanged =
    pkgs.runCommand "config-dir-default-unchanged-test"
      {
        SESSION_VARS = "${defaultActivation}/${sessionVarsRelPath}";
      }
      ''
        set -euo pipefail
        grep -q 'CLAUDE_CONFIG_DIR' "$SESSION_VARS" && {
          echo "expected no CLAUDE_CONFIG_DIR export at the default configDir, but found one in $SESSION_VARS" >&2
          exit 1
        }
        grep -q '/\.claude/settings\.json' ${defaultActivation}/activate || {
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
}
