# Claude Code Hooks
#
# Generates executable scripts in ~/.claude/hooks/ from the typed hook
# options (preToolUse, postToolUse, …) declared in `./options-events.nix`.
#
# Two high-level convenience toggles auto-wire common patterns:
#   - hooks.captureSessionOutput → postToolUse runs `last-output.sh`
#   - hooks.refreshMarketplaces  → sessionStart runs `marketplace-refresh.sh`
{ config, lib, ... }:
let
  cfg = config.programs.claude;

  hookMapping = {
    preToolUse = "pre-tool-use.sh";
    postToolUse = "post-tool-use.sh";
    userPromptSubmit = "user-prompt-submit.sh";
    stop = "stop.sh";
    subagentStop = "subagent-stop.sh";
    sessionStart = "session-start.sh";
    sessionEnd = "session-end.sh";
  };

  mkHookFile =
    _hookName: fileName: hookValue:
    if hookValue == null then
      { }
    else if builtins.isPath hookValue then
      {
        ".claude/hooks/${fileName}" = {
          source = hookValue;
          executable = true;
        };
      }
    else
      {
        ".claude/hooks/${fileName}" = {
          text = hookValue;
          executable = true;
        };
      };

  allHookFiles = lib.mapAttrs' (
    hookName: fileName: lib.nameValuePair hookName (mkHookFile hookName fileName cfg.hooks.${hookName})
  ) hookMapping;

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
  ];

  config = lib.mkMerge [
    # Convenience toggles: wire vendored hook scripts. `mkDefault` so a
    # user setting an explicit hook value at the same path always wins.
    (lib.mkIf (cfg.enable && cfg.hooks.captureSessionOutput) {
      programs.claude.hooks.postToolUse = lib.mkDefault ./hooks/last-output.sh;
    })
    (lib.mkIf (cfg.enable && cfg.hooks.refreshMarketplaces) {
      programs.claude.hooks.sessionStart = lib.mkDefault ./hooks/marketplace-refresh.sh;
    })

    # Materialize all configured hooks as executable files.
    (lib.mkIf cfg.enable {
      home.file = hookFiles;
    })
  ];
}
