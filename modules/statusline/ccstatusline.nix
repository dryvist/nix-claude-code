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

  # Plan-usage widget: renders the 5h and 7d rate-limit windows from the same
  # stdin payload. ccstatusline's built-in session-usage/weekly-usage widgets
  # instead poll api.anthropic.com/api/oauth/usage, which rate-limits hard
  # enough that they render "[Rate limited]" indefinitely. Emits nothing when
  # the payload carries no rate_limits object.
  usageStatus = pkgs.writeShellScript "claude-usage-status" ''
    exec ${pkgs.jq}/bin/jq -rj -f ${./usage-status.jq}
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
