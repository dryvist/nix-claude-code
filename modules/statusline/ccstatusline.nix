{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude.statusline;
  active = config.programs.claude.enable && cfg.enable && cfg.theme == "ccstatusline";

  # Prompt-cache widget: renders the statusline payload's `prompt_cache`
  # object (warm/cold, TTL countdown to `expires_at`, hit ratio, re-cache
  # cost). ccstatusline pipes the full Claude payload JSON to custom-command
  # widgets on stdin. Emits nothing until caching is observed.
  cacheStatus = pkgs.writeShellScript "claude-cache-status" ''
    exec ${pkgs.jq}/bin/jq -rj -f ${./cache-status.jq}
  '';

  # Hourly refresher for the plan-usage snapshot, detached from the render so
  # the widget never waits on the network. The request cadence it enforces is
  # load-bearing — see the script.
  usageRefresh = pkgs.writeShellScript "claude-usage-refresh" ''
    exec ${pkgs.python3}/bin/python3 ${./usage-refresh.py} "$1"
  '';

  # Plan-usage widget: reads the 5h and 7d windows off the stdin payload, and
  # falls back to the cached snapshot when the payload carries none.
  usageStatus = pkgs.runCommand "claude-usage-status" { } ''
    ${pkgs.gnused}/bin/sed -e 's|@jq@|${pkgs.jq}/bin/jq|g' \
      -e 's|@refresh@|${usageRefresh}|' \
      -e 's|@filter@|${./usage-status.jq}|' ${./usage-status.sh} > $out
    chmod +x $out
  '';

  # The committed config carries @cacheStatus@ and @usageStatus@ placeholders
  # for the custom-command paths; inject the store paths at build time.
  configFile = pkgs.runCommand "ccstatusline.json" { } ''
    ${pkgs.gnused}/bin/sed -e 's|@cacheStatus@|${cacheStatus}|' \
      -e 's|@usageStatus@|${usageStatus}|' ${./ccstatusline.json} > $out
  '';

  script = pkgs.writeShellScript "claude-ccstatusline" ''
    # sirmalloc/ccstatusline (semver-pinned for stability)
    export PATH="${pkgs.git}/bin:$PATH"
    exec ${pkgs.bun}/bin/bunx ccstatusline@'^2' --config ${configFile} "$@"
  '';
in
{
  config = lib.mkIf active {
    programs.claude.settings.statusLine = {
      type = "command";
      command = "${script}";
      inherit (cfg) padding;
    };
  };
}
