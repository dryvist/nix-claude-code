{ lib }:
let
  allow = import ../data/permissions/allow.nix { inherit lib; };
  ask = import ../data/permissions/ask.nix { inherit lib; };
  deny = import ../data/permissions/deny.nix { inherit lib; };
  domains = import ../data/permissions/domains.nix { inherit lib; };
  toolSpecific = import ../data/permissions/tool-specific.nix { inherit lib; };
in
{
  inherit
    allow
    ask
    deny
    domains
    toolSpecific
    ;
}
