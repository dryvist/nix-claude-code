# Register each configured typed hook (modules/hooks.nix writes the
# script file; this makes Claude Code actually invoke it) under its
# Claude Code event name. modules/settings.nix appends settings.hooks entries
# for the same event.
#
# The sessionStart entry carries the marketplace refresh, which runs one
# `claude plugin update` per enabled plugin (~1s each, serial). It only needs
# to run once per process start, so it matches `startup` alone (not
# resume/clear/compact) and runs async with a timeout so it never holds up the
# session; updated plugins take effect from the next start.
{ lib, cfg }:
let
  hookEventMapping = import ./hook-event-mapping.nix;
in
lib.mapAttrs' (
  hookName: mapping:
  let
    isRefresh = hookName == "sessionStart" && cfg.hooks.refreshMarketplaces;
  in
  lib.nameValuePair mapping.claudeEvent [
    {
      matcher = if isRefresh then "startup" else "";
      hooks = [
        (
          {
            type = "command";
            command = "${cfg.configDirAbs}/hooks/${mapping.fileName}";
          }
          // lib.optionalAttrs isRefresh {
            async = true;
            timeout = 300;
          }
        )
      ];
    }
  ]
) (lib.filterAttrs (hookName: _: cfg.hooks.${hookName} != null) hookEventMapping)
