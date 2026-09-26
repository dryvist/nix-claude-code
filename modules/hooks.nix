# Claude Code Hooks
#
# Generates executable scripts in ~/.claude/hooks/ from the typed hook
# options (preToolUse, postToolUse, …) declared in `./options-events.nix`.
# `~/.claude/` here is the default `programs.claude.configDir`; the actual
# path follows whatever the caller sets it to.
#
# High-level convenience toggles auto-wire common patterns:
#   - hooks.refreshMarketplaces  → sessionStart runs `marketplace-refresh.sh`
#   - hooks.blockExternalSubagentsInPrivateWorkspace
#                                → preToolUse runs `private-workspace-agent-guard.sh`
#   - hooks.blockKeychainSecretReads
#                                → preToolUse runs `keychain-secret-read-guard.sh`
#   - hooks.worktreesUnderRepo   → worktreeCreate/worktreeRemove run the git
#                                  commands in `lib/worktree-hook-commands.nix`
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude;

  hookEventMapping = import ../lib/hook-event-mapping.nix;
  worktreeHookCommands = import ../lib/worktree-hook-commands.nix;

  mkHookFile =
    _hookName: fileName: hookValue:
    if hookValue == null then
      { }
    else if builtins.isPath hookValue then
      {
        "${cfg.configDir}/hooks/${fileName}" = {
          source = hookValue;
          executable = true;
        };
      }
    else
      {
        "${cfg.configDir}/hooks/${fileName}" = {
          text = hookValue;
          executable = true;
        };
      };

  allHookFiles = lib.mapAttrs' (
    hookName: mapping:
    lib.nameValuePair hookName (mkHookFile hookName mapping.fileName cfg.hooks.${hookName})
  ) hookEventMapping;

  # lib.mkMerge is for option values, not attrsets; flatten manually.
  hookFiles = lib.foldl' (a: b: a // b) { } (builtins.attrValues allHookFiles);
in
{
  imports = [
    # Back-compat for the pre-port flat `extraHooks` option. The freeform
    # pass-through equivalent is now `settings.hooks` — the merger in
    # `./settings.nix` and `lib.toSettingsJson` writes whatever lands
    # under `programs.claude.settings.hooks` straight into settings.json.
    (lib.mkRenamedOptionModule
      [ "programs" "claude" "hooks" "extraHooks" ]
      [ "programs" "claude" "settings" "hooks" ]
    )
    (lib.mkRemovedOptionModule [
      "programs"
      "claude"
      "hooks"
      "captureSessionOutput"
    ] "It ran on every tool call and nothing consumed its output.")
  ];

  config = lib.mkMerge [
    # Convenience toggles: wire vendored hook scripts. `mkDefault` so a
    # user setting an explicit hook value at the same path always wins.
    (lib.mkIf (cfg.enable && cfg.hooks.refreshMarketplaces) {
      programs.claude.hooks.sessionStart = lib.mkDefault ''
        #!${pkgs.runtimeShell}
        exec ${
          pkgs.writeShellApplication {
            name = "marketplace-refresh";
            runtimeInputs = [ pkgs.jq ];
            text = builtins.readFile ./hooks/marketplace-refresh.sh;
          }
        }/bin/marketplace-refresh "$@"
      '';
    })
    (lib.mkIf (cfg.enable && cfg.hooks.blockExternalSubagentsInPrivateWorkspace) {
      programs.claude.hooks.preToolUse = lib.mkDefault ./hooks/private-workspace-agent-guard.sh;
    })
    (lib.mkIf (cfg.enable && cfg.hooks.blockKeychainSecretReads) {
      programs.claude.hooks.preToolUse = lib.mkDefault ./hooks/keychain-secret-read-guard.sh;
    })
    (lib.mkIf (cfg.enable && cfg.hooks.worktreesUnderRepo) {
      programs.claude.hooks.worktreeCreate = lib.mkDefault worktreeHookCommands.create;
      programs.claude.hooks.worktreeRemove = lib.mkDefault worktreeHookCommands.remove;
    })

    # Materialize all configured hooks as executable files.
    (lib.mkIf cfg.enable {
      home.file = hookFiles;
    })
  ];
}
