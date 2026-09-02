# Claude Code Plugin Management
#
# Symlinks Nix-managed plugin directories from flake inputs as single directory
# symlinks. Claude Code only READS from ~/.claude/plugins/marketplaces/ — it
# writes exclusively to ~/.claude/plugins/cache/. Since marketplaces are
# read-only, immutable nix store symlinks are the correct approach.
#
# Delivered by activation script, NOT by `home.file`. `home.file` routes every
# path through the aggregate `home-manager-files` derivation, whose hash covers
# the entire home configuration — so each marketplace symlink acquired a new
# target on every rebuild even when the marketplace itself had not changed.
# Sessions resolve plugin and hook paths once at startup and installed_plugins.json
# pins an installPath, so that churn broke every running session until the user
# reloaded plugins by hand. Linking each marketplace at its own store path means
# the target moves only when that marketplace's content moves.
#
# This also makes verify-cache-integrity.sh accurate rather than merely busy: it
# hashes `readlink` of each marketplace, so it now purges caches only when a
# marketplace genuinely changed.
#
# IMPORTANT: Do NOT move these back to `home.file`, and do not add
# `recursive = true`: per-file symlinks allow .backup pollution of the cache.
# Phase 1 of orphan-cleanup.nix handles the one-time migration from
# recursive (real dirs) to directory symlinks.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude;

  # Extract marketplace name from the identifier
  # e.g., "anthropics/claude-plugins-official" -> "claude-plugins-official"
  # Implementation matches lib/claude-registry.nix for consistency
  getMarketplaceName = name: lib.last (lib.splitString "/" name);

  # Create symlink entries for Nix-managed marketplaces
  nixManagedMarketplaces = lib.filterAttrs (_: m: m.flakeInput != null) cfg.plugins.marketplaces;

  # Apply overlayFiles automatically via symlinkJoin when non-empty.
  # Marketplaces without overlays use raw flakeInput (no-op path).
  effectiveSource =
    name: marketplace:
    if marketplace.overlayFiles == { } then
      marketplace.flakeInput
    else
      pkgs.symlinkJoin {
        name = "${getMarketplaceName name}-with-overlays";
        paths = [
          marketplace.flakeInput
        ]
        ++ lib.mapAttrsToList (
          destPath: srcFile: pkgs.writeTextDir destPath (builtins.readFile srcFile)
        ) marketplace.overlayFiles;
      };

  # `home-relative path -> store path`, consumed by the activation linker.
  marketplaceLinks = lib.mapAttrs' (
    name: marketplace:
    lib.nameValuePair ".claude/plugins/marketplaces/${getMarketplaceName name}" (
      effectiveSource name marketplace
    )
  ) nixManagedMarketplaces;

  inherit (import ../lib/stable-links.nix { inherit lib pkgs; }) mkStableLinks;

in
{
  imports = [
    # Schema rename: flat -> nested. Pre-port, options lived at
    # programs.claude.{enabledPlugins, marketplaces}; the canonical names
    # are now programs.claude.plugins.{enabled, marketplaces}.
    (lib.mkRenamedOptionModule
      [ "programs" "claude" "enabledPlugins" ]
      [ "programs" "claude" "plugins" "enabled" ]
    )
    (lib.mkRenamedOptionModule
      [ "programs" "claude" "marketplaces" ]
      [ "programs" "claude" "plugins" "marketplaces" ]
    )
  ];

  config = lib.mkIf cfg.enable {
    # Ordered explicitly ahead of linkGeneration (see lib/stable-links.nix), so
    # the links are in place before anything sequenced after it reads the
    # directory — orphan-cleanup's verifyCacheIntegrity above all, which would
    # otherwise hash an empty marketplaces dir.
    home.activation.claudeMarketplaceStableLinks = mkStableLinks "claude-marketplaces" marketplaceLinks;
  };
}
