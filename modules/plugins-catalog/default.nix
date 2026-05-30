# Plugin catalog (simplified tier-file aggregator)
#
# The canonical marketplace catalog. Per-user enabledPlugins tier files
# (01-official, 02-vendors, …) stay in the consumer (e.g. nix-ai) — this
# repo only exports the marketplace catalog itself so any consumer can pick
# the plugins they want to enable.
{ lib, ... }:
let
  marketplacesModule = import ./marketplaces.nix { inherit lib; };
in
{
  inherit (marketplacesModule) marketplaces;
}
