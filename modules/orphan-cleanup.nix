# Orphan Cleanup Module
#
# Three-phase cleanup for Nix-managed directories:
#
# Phase 1 (BEFORE checkLinkTargets):
# - Removes directory symlinks and real directories that conflict with
#   directory symlinks in the new generation.
# - Also removes stale root-level symlinks whose nix store targets no longer exist.
# - Must run before checkLinkTargets because cmp(1) fails on directories, causing
#   checkLinkTargets to abort before any backup/link logic can run.
#
# Phase 2 (AFTER linkGeneration):
# - Removes broken symlinks (targets that no longer exist) inside component dirs.
#
# Phase 3 (AFTER linkGeneration):
# - Verifies plugin cache integrity when marketplace symlinks change.
#
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;

  # Resolve any `~` prefix in user-supplied dirs against the home directory
  # so callers can write `extraComponentDirs = [ "~/.gemini/commands" ]`.
  expandHome = p: if lib.hasPrefix "~/" p then "${homeDir}/${lib.removePrefix "~/" p}" else p;

  baseComponentDirs = [
    "${homeDir}/.claude/commands"
    "${homeDir}/.claude/agents"
    "${homeDir}/.claude/skills"
    "${homeDir}/.claude/rules"
  ];

  componentDirs = baseComponentDirs ++ map expandHome cfg.orphanCleanup.extraComponentDirs;

  getMarketplaceName = name: lib.last (lib.splitString "/" name);
  nixManagedMarketplaces = lib.filterAttrs (_: m: m.flakeInput != null) cfg.plugins.marketplaces;
  marketplaceDirs = lib.mapAttrsToList (
    name: _: "${homeDir}/.claude/plugins/marketplaces/${getMarketplaceName name}"
  ) nixManagedMarketplaces;

  # Extra-dir label pairs for the cleanup-broken-symlinks pass.
  extraBrokenSymlinkArgs = lib.concatMap (d: [
    "external component"
    d
  ]) (map expandHome cfg.orphanCleanup.extraComponentDirs);

in
{
  options.programs.claude.orphanCleanup = {
    extraComponentDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "~/.gemini/commands" ];
      description = ''
        Additional component directories to include in orphan-cleanup
        phases 1 and 2. Useful when a related tool (Gemini, Codex, etc.)
        ships symlinks under `~/` that should be pruned alongside
        Claude's own directories. `~/` is expanded to the configured home
        directory.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation = {
      # Phase 1: Remove conflicting entries BEFORE checkLinkTargets.
      cleanupConflictingDirectorySymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        . ${./scripts/cleanup-common.sh}
        . ${./scripts/cleanup-conflicting-symlinks.sh} \
          ${lib.escapeShellArgs (componentDirs ++ marketplaceDirs)}
        . ${./scripts/cleanup-stale-symlinks.sh} \
          "${homeDir}/CLAUDE.md" "${homeDir}/GEMINI.md" "${homeDir}/AGENTS.md" "${homeDir}/agentsmd"
      '';

      # Phase 2: Remove orphan symlinks AFTER linkGeneration creates new ones.
      cleanupOrphanComponents = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        . ${./scripts/cleanup-common.sh}
        . ${./scripts/cleanup-broken-symlinks.sh} \
          ${lib.escapeShellArgs (
            [
              "command"
              "${homeDir}/.claude/commands"
              "agent"
              "${homeDir}/.claude/agents"
              "skill"
              "${homeDir}/.claude/skills"
              "rule"
              "${homeDir}/.claude/rules"
            ]
            ++ extraBrokenSymlinkArgs
            ++ (lib.concatMap (dir: [
              "marketplace file"
              dir
            ]) marketplaceDirs)
          )}
      '';

      # Phase 3: Verify plugin cache integrity AFTER linkGeneration.
      # See: https://github.com/anthropics/claude-code/issues/17361
      verifyCacheIntegrity = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD ${./scripts/verify-cache-integrity.sh} "${homeDir}"
      '';
    };
  };
}
