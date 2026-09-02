# Stable store-path links for tool trees home-manager would otherwise route
# through its aggregate.
#
# `home.file` funnels every managed path through one `home-manager-files`
# derivation whose hash covers the whole home configuration. It changes on any
# change at all — an unrelated shell alias will do it — so every symlink under
# it gets a new target on every rebuild even when the content behind it is
# byte-identical.
#
# That churn is what invalidates Claude Code's plugin cache: `installed_plugins.json`
# pins an installPath, sessions resolve plugin and hook paths once at startup,
# and a moved marketplace leaves every running session pointing at a path that
# no longer exists until the user reloads by hand. The same applies to the
# shared skill tree that Codex, Cursor, OpenCode, qwen and Antigravity read.
#
# Linking each entry at its own store path keeps the target byte-stable unless
# that entry's content actually changed, so an unrelated rebuild is invisible.
# It also makes verify-cache-integrity.sh correct rather than merely busy: that
# script hashes `readlink` of each marketplace, so a stable path means it stops
# purging caches that were never stale, while still firing when a marketplace's
# content genuinely changes.
#
# `lib` must be the *module's* lib, not `inputs.nixpkgs.lib` — the activation
# entry needs `lib.hm.dag`, which only home-manager's extended lib provides.
{ lib, pkgs }:
{
  # name  : activation entry name, shown in the generation diff
  # links : { "home-relative/path" = <store path>; }
  mkStableLinks =
    name: links:
    let
      manifest = pkgs.writeText "${name}-stable-links-manifest" (
        lib.concatStringsSep "\n" (lib.mapAttrsToList (rel: target: "${rel}\t${target}") links) + "\n"
      );
    in
    # entryBetween, not entryAfter: home-manager's own `linkGeneration` is
    # itself `entryAfter [ "writeBoundary" ]` (modules/files.nix), so anchoring
    # only on writeBoundary makes this a SIBLING of linkGeneration with no edge
    # between them — the observed order would come from the topo-sort tiebreak
    # on entry names and could flip on a rename or a home-manager bump. The
    # explicit edge keeps these links in place before linkGeneration runs, and
    # therefore before anything ordered after it reads the directory.
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${../modules/scripts/stable-links.sh} ${manifest} "$HOME"
    '';
}
