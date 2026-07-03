# Claude Code Plugin Registry
#
# Marketplace discovery is declared via extraKnownMarketplaces in settings.json.
# known_marketplaces.json is a writable runtime file Claude Code owns, but Nix
# does deep-merge into it: `knownMarketplacesMerge` in settings.nix overlays the
# installLocation/source of every Nix-managed marketplace onto it each activation
# (so Claude reads them from the Nix symlink instead of re-fetching from GitHub).
# This module only performs the one-time migration off the old read-only symlink.
#
# Previously, this module generated known_marketplaces.json as a Nix store
# symlink (read-only), which prevented Claude Code's "Enable auto-update"
# feature from working (EACCES permission denied) and blocked the deep-merge.
{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;
in
{
  config = lib.mkIf cfg.enable {
    # NOTE: known_marketplaces.json is a writable runtime file, but Nix deep-merges
    # into it. Marketplace sources are declared via extraKnownMarketplaces in
    # settings.json, and `knownMarketplacesMerge` in settings.nix overlays each
    # Nix-managed marketplace's installLocation/source onto the file every
    # activation (so Claude reads them locally instead of re-fetching from GitHub).

    # NOTE: installed_plugins.json is runtime state Claude owns; Nix never writes it.
    # When a marketplace store path changes, verify-cache-integrity purges the stale
    # cache and the marketplace-refresh sessionStart hook has Claude natively
    # reinstall the affected enabled plugins, re-pointing their installPath.

    # Migration: Remove stale Nix symlink if it exists
    # After switching from Nix-managed to Claude-managed known_marketplaces.json,
    # the old symlink to /nix/store/... must be removed so Claude Code can create
    # a writable file in its place.
    home.activation.cleanupMarketplacesSymlink = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      MARKETPLACES="${homeDir}/.claude/plugins/known_marketplaces.json"
      . ${./scripts/cleanup-marketplaces-symlink.sh}
    '';
  };
}
