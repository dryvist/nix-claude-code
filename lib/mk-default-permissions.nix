{ lib }:
{
  tool ? "claude",
}:
let
  permissions = import ./permissions.nix { inherit lib; };
  forTool = permissions.toolSpecific.${tool} or { };
in
{
  allow = permissions.allow ++ (forTool.allow or [ ]);
  ask = permissions.ask ++ (forTool.ask or [ ]);
  deny = permissions.deny ++ (forTool.deny or [ ]);
  webfetchDomains = permissions.domains.webfetch or [ ];
}
