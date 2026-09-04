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

  # The committed config carries an @cacheStatus@ placeholder for the
  # custom-command path; inject the store path at build time.
  configFile = pkgs.runCommand "ccstatusline.json" { } ''
    ${pkgs.gnused}/bin/sed 's|@cacheStatus@|${cacheStatus}|' ${./ccstatusline.json} > $out
  '';

  script = pkgs.writeShellScript "claude-ccstatusline" ''
    # sirmalloc/ccstatusline, pinned to an exact version for reproducible
    # rendering (a floating range lets bunx silently resolve a newer
    # version between sessions). Bump deliberately, not automatically.
    export PATH="${pkgs.git}/bin:$PATH"
    exec ${pkgs.bun}/bin/bunx ccstatusline@'2.2.27' --config ${configFile} "$@"
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
